fetch = require('isomorphic-fetch')

class GitlabStatus
    constructor: (@view, @timeout=null, @projects={}, @pending=[], @jobs={}) ->
        @host = atom.config.get('gitlab-integration.host')
        @token = atom.config.get('gitlab-integration.token')
        @period = atom.config.get('gitlab-integration.period')

    fetch: (q) ->
        fetch(
            "https://#{@host}/api/v4/#{q}", {
                headers: {
                    "PRIVATE-TOKEN": @token,
                }
            }
        ).then((res) => res.json())

    watch: (projectPath) ->
        if not @projects[projectPath]?
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
                if project?
                    if not @jobs[projectPath]?
                        @view.loading(projectPath, "loading pipelines...")
                    @fetch("projects/#{project.id}/pipelines").then(
                        (pipelines) =>
                            @updateJobs(project, pipelines[0])
                    )
        )

    endUpdate: (project) ->
        @pending = @pending.filter((pending) => pending isnt project)
        if @pending.length is 0
            @view.onStagesUpdate(@jobs)
            @schedule()

    updateJobs: (project, pipeline) ->
        if not @jobs[project.path_with_namespace]?
            @view.loading(project.path_with_namespace, "loading jobs...")
        @fetch("projects/#{project.id}/" + "pipelines/#{pipeline.id}/jobs")
        .then((jobs) =>
            @onJobs(project, jobs.reverse().reduce(
                (stages, job) =>
                    stage = stages.find(
                        (stage) => stage.name is job.stage
                    )
                    if not stage?
                        stage =
                            name: job.stage
                            status: 'success'
                        stages = stages.concat([stage])
                    if job.status isnt 'success'
                        stage.status = job.status
                    return stages
            , []))
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
