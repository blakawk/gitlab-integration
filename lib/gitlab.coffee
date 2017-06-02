request = require('request')

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
        @project = @origin.split(':')[1].split('/')[..1].join('/')
        request({
            url: "https://#{@host}/api/v4/projects",
            headers: {
                "PRIVATE-TOKEN": @token,
            }
        }, (e, r, b) =>
            @response({ error: e, response: r, body: b })
        )

    response: (answer) =>
        console.log answer
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
