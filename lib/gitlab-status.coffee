class GitlabStatus
    constructor: (@view) ->
    newOrigin: (@origin) ->
        console.log 'new origin', @origin

module.exports = GitlabStatus
