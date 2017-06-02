Request = require('request')

class StatusBarView extends HTMLElement
    init: ->
        @classList.add('status-bar-gitlab', 'inline-block')
        @activate()

    activate: ->
        @intervalId = setInterval @update.bind(@), 1000

        atom.config.get('atom-gitlab.gitlab-uri')
        atom.config.get('atom-gitlab.gitlab-token')

    onDisplay: (callback) ->
        @display = callback

    deactivate: ->
        clearInterval @intervalId

    update: ->
        @textContent = "gitlab"

module.exports = document.registerElement 'status-bar-gitlab',
    prototype: StatusBarView.prototype, extends: 'div'
