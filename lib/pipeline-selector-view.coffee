{$, $$, SelectListView} = require 'atom-space-pen-views'
percentile = require 'percentile'
moment = require 'moment'

Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

class PipelineSelectorView extends SelectListView
  initialize: (pipelines, controller, projectPath) ->
    super

    @pipelines = pipelines
    @controller = controller
    @projectPath = projectPath

    @addClass('overlay from-top')
    @setItems pipelines
    @calculate()
    @panel ?= atom.workspace.addModalPanel(item: this)
    @focusFilterEditor()
    $$(@extraContent(@)).insertBefore(@error)
    @handleEvents()
    @panel.show()

  getFilterKey: -> 'search'

  extraContent: (thiz) ->
    return ->
      alwaysSuccess = thiz.asUniqueNames(thiz.alwaysSuccess)
      unstable = thiz.asUniqueNames(thiz.unstable)
      alwaysFailed = thiz.asUniqueNames(thiz.alwaysFailed)

      @div class: 'block', =>
        @div class: 'block', =>
          @span class: 'icon icon-git-branch', " #{thiz.branch}"

        @div class: 'block', =>
          @raw "
          <div class='block'>
            <i class='text-info'> All 50% ♨︎ #{thiz.controller.toHHMMSS(thiz.averageDuration)}</i>
            <i class='text-error'> All MAX ♨︎ #{thiz.controller.toHHMMSS(thiz.maxDuration)}</i>
          </div>
          "

          if thiz.maxDurationSuccess
            @raw "<div class='block'>
              <i class='text-info'> Success 50% ♨︎ #{thiz.controller.toHHMMSS(thiz.averageDurationSuccess)}</i>
              <i class='text-error'> Sucess MAX ♨︎ #{thiz.controller.toHHMMSS(thiz.maxDurationSuccess)}</i>
            </div>
            "

          @raw "<div class='block'>
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

        @div class: 'block', =>
          @div class: 'btn-group', =>
            @button outlet: 'sortById', class: 'btn', ' Sort by id'
            @button outlet: 'sortBySha', class: 'btn', ' Sort by sha'
            @button outlet: 'sortByDate', class: 'btn', ' Sort by date'

  handleEvents: ->
    @wireOutlets(@)

    @sortById.on 'mouseover', (e) =>
      @setItems @items.sort (a, b) ->
        return a.id - b.id

    @sortBySha.on 'mouseover', (e) =>
      @setItems @items.sort (a, b) ->
        return -1 if a.sha < b.sha
        return 1 if a.sha > b.sha
        return 0

    @sortByDate.on 'mouseover', (e) =>
      @setItems @items.sort (a, b) ->
        if a.created_at and b.created_at
          return moment(b.created_at).diff(moment(a.created_at))
        else
          return 0

  calculate: () ->
    if @items?.length > 0
      @branch = @items[0].ref

    @maxDuration = @items?.reduce( ((max, p) ->
      Math.max(max, p.duration || 0)
    ), 0 )
    @averageDuration = percentile(50, @items, (item) -> item.duration).duration

    success = @items.filter( (p) -> p.status is 'success')
    if success?.length > 0
      @maxDurationSuccess = success?.reduce( ((max, p) ->
        Math.max(max, p.durationSuccess || 0)
      ), 0 )
      @averageDurationSuccess = percentile(50, success, (item) -> item.durationSuccess).durationSuccess

    allJobs = @items.reduce(((all, p) ->
      if p.loadedJobs?.length > 0
        all.concat(p.loadedJobs)
      else
        all
      ), [])

    {@alwaysSuccess, @unstable, @alwaysFailed, @total} = @controller.statistics(allJobs)

  asUniqueNames: (jobs) =>
    return jobs.map((j) => j.name).unique()

  viewForItem: (pipeline) ->
    pipeline.elapsed = moment(pipeline.finished_at).diff(moment(pipeline.created_at), 'seconds')

    if pipeline.loadedJobs?.length > 0
      {alwaysSuccess, unstable, alwaysFailed, total} = @controller.statistics(pipeline.loadedJobs)

      type = @controller.toType(pipeline, @averageDuration)

      "<li class='two-lines'>
        <div class='status icon icon-git-commit'></div>
        <div class='primary-line icon gitlab-#{pipeline.status}'>
          #{pipeline.id}
          <span class='text-muted icon icon-clock'> #{moment(pipeline.created_at).format('lll')} / #{moment(pipeline.created_at).fromNow()}</span>
          <span class='pull-right'>
            <span class='text-info'>#{pipeline.commit?.short_id}</span>
          </span>
        </div>
        <div class='secondary-line no-icon'>
          <div class='block'>
            <span class='text-muted'>#{pipeline.commit?.title}</span>
          </div>
          <div class='block'>
            <progress class='inline-block progress-#{type}' max='#{@maxDuration}' value='#{pipeline.duration}'></progress>
            <i class='text-muted'> ♨︎ #{@controller.toHHMMSS(pipeline.duration)}</i>
            <span class='text-warning'> / ABS #{@controller.toHHMMSS(pipeline.elapsed)}</span>
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
          <span class='badge badge-error'>#{alwaysFailed.length}</span>
          <span class='pull-right'>
            <img src='#{pipeline.user?.avatar_url}' class='gitlab-avatar' /> #{pipeline.user?.name}
          </span>
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
