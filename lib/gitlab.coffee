fetch = require('isomorphic-fetch')

class GitlabStatus
    constructor: (@view, @token=null, @timeout=null, @origin=null, @projects={}, @pending=[], @jobs={}) ->
    fetch: (q) =>
        fetch(
            "https://#{@host}/api/v4/#{q}", {
                headers: {
                    "PRIVATE-TOKEN": @token,
                }
            }
        ).then((res) => res.json())
    newOrigin: (origin) =>
        if origin isnt @origin
            @token = atom.config.get('gitlab-integration.token')
            @host = atom.config.get('gitlab-integration.host')
            if @token isnt ''
                if origin?
                    @start(origin)
                else
                    @stop()
            else
                console.log "no token configured"

    start: (@origin) =>
        console.log "start", @origin
        project = @origin.split(':')[1].split('/')[..1].join('/').replace(/\.git$/, '')
        @addProject project

    watch: (projectPath) =>
        if not @projects[projectPath]?
            @fetch("projects?membership=yes").then(
                (projects) =>
                    @projects[projectPath] = projects.filter(
                        (project) =>
                            project.path_with_namespace is projectPath
                    )[0]
                    console.log "added project", projectPath, @projects[projectPath]
                    @update()
            )

    schedule: =>
        @timeout = setTimeout @update, atom.config.get('gitlab-integration.period')

    update: =>
        console.log "update", Object.keys(@projects).join(", ")
        @pending = Object.keys(@projects).slice()
        @updatePipelines()

    updatePipelines: =>
        Object.keys(@projects).forEach(
            (projectPath) =>
                project = projects[projectPath]
                if project?
                    @fetch("projects/#{project.id}/pipelines").then(
                        (pipelines) =>
                            @updateJobs(project, pipelines[0])
                    )
        )

    endUpdate: (project) =>
        console.log "end of update", project
        @pending = @pending.filter((pending) => pending isnt project)
        console.log "still pending", @pending.join()
        if @pending.length is 0
            @view.onStagesUpdate(@jobs)
            @schedule()

    updateJobs: (project, pipeline) =>
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

    onJobs: (project, stages) =>
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
