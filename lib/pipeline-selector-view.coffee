{$, $$, SelectListView} = require 'atom-space-pen-views'
percentile = require('percentile')

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

    success = pipelines.filter( (p) -> p.status is 'success')
    @maxDuration = success.reduce( ((max, p) ->
      Math.max(max, p.duration)
    ), 0 )
    @averageDuration = percentile(50, success, (item) -> item.duration).duration

    allJobs = pipelines.reduce(((all, p) ->
      all.concat(p.loadedJobs)), [])

    {@alwaysSuccess, @unstable, @alwaysFailed, @total} = @controller.statistics(allJobs)

    @setItems pipelines

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()
    @getFilterKey = -> 'sha'
    @loadingArea.append $ @extraContent()
    @loadingArea.show()

  extraContent: ->
    alwaysSuccess = @asUniqueNames(@alwaysSuccess)
    unstable = @asUniqueNames(@unstable)
    alwaysFailed = @asUniqueNames(@alwaysFailed)

    "<div class='inline-block'>
      <i class='text-info'> 50% ♨︎ #{@controller.toHHMMSS(@averageDuration)}</i>
      <i class='text-error'> MAX ♨︎ #{@controller.toHHMMSS(@maxDuration)}</i>
    </div>
    <div class='block'>
      <span class='text-success'>STABLE: #{alwaysSuccess}</span>
    </div>
    <div class='block'>
      <span class='text-warning'>UNSTABLE: #{unstable}</span>
    </div>
    <div class='block'>
      <span class='text-error'>ERROR: #{alwaysFailed}</span>
    </div>
    <div class='block'>
      <span class='badge badge-success'>#{alwaysSuccess.length}</span>
      <span class='badge badge-warning'>#{unstable.length}</span>
      <span class='badge badge-error'>#{alwaysFailed.length}</span>
    </div>"

  asUniqueNames: (jobs) =>
    return jobs.map((j) => j.name).unique()

  viewForItem: (pipeline) ->
    if pipeline.loadedJobs
      {alwaysSuccess, unstable, alwaysFailed, total} = @controller.statistics(pipeline.loadedJobs)

      type = @controller.toType(pipeline, @averageDuration)

      "<li class='two-lines'>
        <div class='status status-added icon icon-git-commit'></div>
        <div class='primary-line icon gitlab-#{pipeline.status}'>
          #{pipeline.id}
          <span class='pull-right'>#{pipeline.ref} / #{pipeline.sha?.substring(0,5)}</span>
          <span class='text-muted'>#{pipeline.commit?.message}</span>
        </div>
        <div class='secondary-line no-icon'>
          <div class='block'>
            <progress class='inline-block progress-#{type}' max='#{@maxDuration}' value='#{pipeline.duration}'></progress>
            <i class='text-muted'> ♨︎ #{@controller.toHHMMSS(pipeline.duration)}</i>
          </div>
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
          <span class='text-muted'>#{pipeline.commit?.message}</span>
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
