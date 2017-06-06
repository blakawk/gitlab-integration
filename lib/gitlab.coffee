fetch = require('isomorphic-fetch')

class GitlabStatus
    constructor: (@view, @token=null, @timeout=null, @origin=null) ->
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
        @restart()

    restart: =>
        @timeout = setTimeout @update, atom.config.get('gitlab-integration.period')

    update: =>
        project = @origin.split(':')[1].split('/')[..1].join('/')
        if project isnt @project
            fetch("https://#{@host}/api/v4/projects?membership=yes", {
                headers: {
                    "PRIVATE-TOKEN": @token,
                }
            }).then((res) =>
                @project = project
                res.json().then((answer) =>
                    @onProject(answer.filter(
                        (project) => project.path_with_namespace is @project
                    )[0])
                )
            )

    onProject: (project) =>
        fetch("https://#{@host}/api/v4/projects/#{project.id}/pipelines", {
            headers: {
                "PRIVATE-TOKEN": @token,
            }
        }).then((res) =>
            res.json().then(
                (answer) =>
                    @onPipeline(project, answer[0])
            )
        )

    onPipeline: (project, pipeline) =>
        fetch("https://#{@host}/api/v4/projects/#{project.id}/" + "pipelines/#{pipeline.id}/jobs", {
                headers: {
                    "PRIVATE-TOKEN": @token,
                }
            }
        ).then((res) =>
            res.json().then(
                (answer) =>
                    @onJobs(answer.reduce(
                        (stages, job) =>
                            if not stages[job.stage]?
                                stages[job.stage] = []
                            stages[job.stage].concat([job])
                    , {}))
            )
        )

    onJobs: (stages) =>
        console.log stages
        @view.update @project
        @restart()

    stop: ->
        console.log "stop", @origin
        if @timeout?
            clearTimeout @timeout
        [@timeout, @origin] = [null, null]
        @view.hide()

    deactivate: ->
        @stop()

module.exports = GitlabStatus
