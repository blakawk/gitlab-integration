class StatusBarView extends HTMLElement
    init: ->
        @classList.add('status-bar-gitlab', 'inline-block')
        @activate()
        @currentProject = null
        @stages = {}

    activate: => @displayed = false
    deactivate: => @dispose() if @displayed

    onDisplay: (@display) ->
    onDispose: (@dispose) ->

    hide: =>
        @dispose() if @displayed
        @displayed = false

    show: =>
        @display(@) if not @displayed
        @displayed = true

    onProjectChange: (project) =>
        console.log "stages", @stages, "project", project
        @currentProject = project
        if @stages[project]?
            @update(@stages[project])
        else
            @hide()

    onStagesUpdate: (stages) =>
        @stages = stages
        console.log "current", @currentProject, "stages", @stages
        if @stages[@currentProject]?
            @update(@stages[@currentProject])

    update: (stages) =>
        @show()
        console.log 'stages', stages
        status = document.createElement('div')
        status.classList.add('inline-block')
        stages.forEach((stage) =>
            e = document.createElement('span')
            switch
                when stage.status is 'success'
                    console.log stage.name, 'success'
                    e.classList.add('icon', 'icon-verified')
                    e.style.color = 'green'
                when stage.status is 'failed'
                    console.log stage.name, 'failed'
                    e.classList.add('icon', 'icon-issue-opened')
                    e.style.color = 'red'
                when stage.status is 'running'
                    console.log stage.name, 'running'
                    e.classList.add('icon', 'icon-clock')
                    e.style.color = '#1f78d1'
                when stage.status is 'pending' or stage.status is 'created'
                    console.log stage.name, 'pending'
                    e.classList.add('icon', 'icon-history')
                when stage.status is 'skipped'
                    console.log stage.name, 'skipped'
                    e.classList.add('icon', 'icon-unverified')
            status.appendChild e
        )
        if @children.length > 0
            console.log 'replace'
            @replaceChild status, @children[0]
        else
            console.log 'append'
            @appendChild status

module.exports = document.registerElement 'status-bar-gitlab',
    prototype: StatusBarView.prototype, extends: 'div'
