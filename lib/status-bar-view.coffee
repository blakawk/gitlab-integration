{CompositeDisposable} = require('atom')

class StatusBarView extends HTMLElement
    init: ->
        @classList.add('status-bar-gitlab', 'inline-block')
        @activate()
        @currentProject = null
        @stages = {}
        @statuses = {}
        @tooltips = []
        @host = atom.config.get('gitlab-integration.host')

    activate: => @displayed = false
    deactivate: =>
        @disposeTooltips()
        @dispose() if @displayed

    onDisplay: (@display) ->
        if @displayed
            @display(@)

    onDispose: (@dispose) ->

    hide: =>
        @dispose() if @displayed
        @displayed = false

    show: =>
        if @display?
            @display(@) if not @displayed
        @displayed = true

    onProjectChange: (project) =>
        @currentProject = project
        if project?
            if @stages[project]?
                @update(project, @stages[project])
            else
                @loading(project, @statuses[project])

    onStagesUpdate: (stages) =>
        @stages = stages
        if @stages[@currentProject]?
            @update(@currentProject, @stages[@currentProject])

    disposeTooltips: =>
        @tooltips.forEach((tooltip) => tooltip.dispose())
        @tooltips = []

    loading: (project, message) =>
        @statuses[project] = message
        if @currentProject is project
            @show()
            @disposeTooltips()
            status = document.createElement('div')
            status.classList.add('inline-block')
            icon = document.createElement('span')
            icon.classList.add('icon', 'icon-gitlab')
            @tooltips.push atom.tooltips.add icon, {
                title: "GitLab #{@host} project #{project}"
            }
            span = document.createElement('span')
            span.classList.add('icon', 'icon-sync', 'icon-loading')
            @tooltips.push atom.tooltips.add(span, {
                title: message,
            })
            status.appendChild icon
            status.appendChild span
            @setchild(status)

    setchild: (child) =>
        if @children.length > 0
            @replaceChild child, @children[0]
        else
            @appendChild child

    update: (project, stages) =>
        @show()
        @disposeTooltips()
        status = document.createElement('div')
        status.classList.add('inline-block')
        icon = document.createElement('span')
        icon.classList.add('icon', 'icon-gitlab')
        @tooltips.push atom.tooltips.add icon, {
            title: "GitLab #{@host} project #{project}"
        }
        status.appendChild icon
        stages.forEach((stage) =>
            e = document.createElement('span')
            switch
                when stage.status is 'success'
                    e.classList.add('icon', 'gitlab-success')
                when stage.status is 'failed'
                    e.classList.add('icon', 'gitlab-failed')
                when stage.status is 'running'
                    e.classList.add('icon', 'gitlab-running')
                when stage.status is 'pending' or stage.status is 'created'
                    e.classList.add('icon', 'gitlab-created')
                when stage.status is 'skipped'
                    e.classList.add('icon', 'gitlab-skipped')
                when stage.status is 'canceled'
                    e.classList.add('icon', 'gitlab-canceled')
            @tooltips.push atom.tooltips.add e, {
                title: "#{stage.name}: #{stage.status}"
            }
            status.appendChild e
        )
        @setchild(status)

    unknown: (project) =>
        @show()
        @disposeTooltips()
        host = atom.config.get('gitlab-integration.host')
        status = document.createElement('div')
        status.classList.add('inline-block')
        span = document.createElement('span')
        span.classList.add('icon', 'icon-question')
        status.appendChild span
        @tooltips.push atom.tooltips.add(span, {
            title: "no GitLab project detected in #{project}"
        })
        @setchild(status)

module.exports = document.registerElement 'status-bar-gitlab',
    prototype: StatusBarView.prototype, extends: 'div'
