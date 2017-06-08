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
        console.log "watch", projectPath
        if not @projects[projectPath]?
            @fetch("projects?membership=yes").then(
                (projects) =>
                    @projects[projectPath] = projects.filter(
                        (project) =>
                            project.path_with_namespace is projectPath
                    )[0]
                    @update()
            )

    schedule: ->
        @timeout = setTimeout @update.bind(@), @period

    update: ->
        console.log "update"
        @pending = Object.keys(@projects).slice()
        @updatePipelines()

    updatePipelines: ->
        Object.keys(@projects).forEach(
            (projectPath) =>
                project = @projects[projectPath]
                if project?
                    console.log "update pipelines", project
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
        console.log "stop", @origin
        if @timeout?
            clearTimeout @timeout
        [@timeout, @origin] = [null, null]
        @view.hide()

    deactivate: ->
        @stop()

module.exports = GitlabStatus
