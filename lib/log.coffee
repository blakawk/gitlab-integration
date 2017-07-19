debug = atom.config.get('gitlab-integration.debug')

module.exports = (args...) ->
    console.log.apply(null, ['[gitlab-integration]'].concat(args)) if debug
