fetch = require('isomorphic-fetch')

class GitlabStatus
    constructor: (@view, @timeout=null, @projects={}, @pending=[], @jobs={}) ->
        @host = atom.config.get('gitlab-integration.host')
        @token = atom.config.get('gitlab-integration.token')
        @period = atom.config.get('gitlab-integration.period')
        @updating = {}

    fetch: (q) ->
        fetch(
            "https://#{@host}/api/v4/#{q}", {
                headers: {
                    "PRIVATE-TOKEN": @token,
                }
            }
        ).then((res) => res.json())

    watch: (projectPath) ->
        if not @projects[projectPath]? and not @updating[projectPath]?
            @updating[projectPath] = false
            @view.loading projectPath, "loading project..."
            @fetch("projects?membership=yes").then(
                (projects) =>
                    if projects?
                        project = projects.filter(
                            (project) =>
                                project.path_with_namespace is projectPath
                        )[0]
                        if project?
                            @projects[projectPath] = project
                            @update()
                        else
                            @view.unknown(projectPath)
                    else
                        @view.unknown(projectPath)
            ).catch(=>
                @updating[projectPath] = undefined
                setTimeout => @watch.bind(@)(projectPath) @timeout
            )

    schedule: ->
        @timeout = setTimeout @update.bind(@), @period

    update: ->
        @pending = Object.keys(@projects).slice()
        @updatePipelines()

    updatePipelines: ->
        Object.keys(@projects).forEach(
            (projectPath) =>
                project = @projects[projectPath]
                if project? and project.id? and not @updating[projectPath]
                    @updating[projectPath] = true
                    if not @jobs[projectPath]?
                        @view.loading(projectPath, "loading pipelines...")
                    @fetch("projects/#{project.id}/pipelines").then(
                        (pipelines) =>
                            @updateJobs(project, pipelines[0])
                    )
                    .catch(=>
                        @endUpdate(project)
                    )
        )

    endUpdate: (project) ->
        @updating[project] = false
        @pending = @pending.filter((pending) => pending isnt project)
        if @pending.length is 0
            @view.onStagesUpdate(@jobs)
            @schedule()

    updateJobs: (project, pipeline) ->
        if not @jobs[project.path_with_namespace]?
            @view.loading(project.path_with_namespace, "loading jobs...")
        @fetch("projects/#{project.id}/" + "pipelines/#{pipeline.id}/jobs")
        .then((jobs) =>
            @onJobs(project, jobs.sort((a, b) -> a.id - b.id).reduce(
                (stages, job) =>
                    stage = stages.find(
                        (stage) => stage.name is job.stage
                    )
                    if not stage?
                        stage =
                            name: job.stage
                            status: 'success'
                            jobs: []
                        stages = stages.concat([stage])
                    stage.jobs = stage.jobs.concat([job])
                    return stages
            , []).map((stage) =>
                Object.assign(stage, {
                    status: stage.jobs.sort((a, b) => b.id - a.id)[0].status,
                })
            ))
        ).catch(=>
            @endUpdate(project)
        )

    onJobs: (project, stages) ->
        @jobs[project.path_with_namespace] = stages.slice()
        @endUpdate(project.path_with_namespace)

    stop: ->
        if @timeout?
            clearTimeout @timeout
        @view.hide()

    deactivate: ->
        @stop()

module.exports = GitlabStatus
