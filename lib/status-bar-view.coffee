class StatusBarView extends HTMLElement
    init: ->
        @classList.add('status-bar-gitlab', 'inline-block')
        @activate()

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

    update: (project) =>
            @show()
            @textContent = project



module.exports = document.registerElement 'status-bar-gitlab',
    prototype: StatusBarView.prototype, extends: 'div'
