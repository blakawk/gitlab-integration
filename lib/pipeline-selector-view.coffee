{$, $$, SelectListView} = require 'atom-space-pen-views'
moment = require 'moment'
moment.locale('sk')

Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

class PipelineSelectorView extends SelectListView
  initialize: (pipelines, controller, projectPath) ->
    super
    @projectPath = projectPath
    @controller = controller
    @addClass('overlay from-top')

    pipelines?.sort (a, b) ->
      return 1 if a.sha < b.sha
      return -1 if a.sha > b.sha
      return 1 if a.id < b.id
      return -1 if a.id > b.id
      return 0

    @setItems pipelines

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()
    @getFilterKey = -> 'sha'

  asUniqueNames: (jobs) =>
    return jobs.map((j) => j.name).unique()

  viewForItem: (pipeline) ->
    if pipeline.loadedJobs
      {alwaysSuccess, unstable, alwaysFailed, total} = @controller.statistics(pipeline.loadedJobs)

      "<li class='two-lines'>
        <div class='status status-added icon icon-git-commit'></div>
        <div class='primary-line icon gitlab-#{pipeline.status}'>
          #{pipeline.id}
          <span class='pull-right'>#{pipeline.sha}</span>
        </div>
        <div class='secondary-line no-icon'>
          <span class='text-success'>#{@asUniqueNames(alwaysSuccess)}</span>
          <div class='block'>
            <span class='text-warning'>#{@asUniqueNames(unstable)}</span>
          </div>
          <div class='block'>
            <span class='text-error'>#{@asUniqueNames(alwaysFailed)}</span>
          </div>
          <span class='badge badge-info'>#{total.length}</span>
          <span class='badge badge-success'>#{alwaysSuccess.length}</span>
          <span class='badge badge-warning'>#{unstable.length}</span>
          <span class='badge badge-error'>#{alwaysFailed.length}</span>
      </li>"
    else
      "<li class='two-lines'>
        <div class='status status-added icon icon-git-commit'></div>
        <div class='primary-line icon gitlab-#{pipeline.status}'>
          #{pipeline.id}
          <span class='pull-right'>#{pipeline.sha}</span>
        </div>
        <div class='secondary-line no-icon'>
          <span class='loading loading-spinner-tiny inline-block'></span>
        </div>
      </li>"

  confirmed: (pipeline) =>
    @cancel()
    @controller.updatePipeline(pipeline, @projectPath);

  cancelled: ->
    @panel.hide()

module.exports = PipelineSelectorView
