{$, $$, SelectListView} = require 'atom-space-pen-views'
percentile = require('percentile')
moment = require 'moment'
# moment.locale('sk')
class JobSelectorView extends SelectListView
  initialize: (jobs, controller, projectPath) ->
    super

    @jobs = jobs
    @controller = controller
    @projectPath = projectPath
    @addClass('overlay from-top')

    jobs?.sort (a, b) ->
      return -1 if a.name < b.name
      return 1 if a.name > b.name
      return -1 if a.id < b.id
      return 1 if a.id > b.id
      return 0

    success = jobs.filter( (j) -> j.status is 'success')
    @maxDuration = success.reduce( ((max, j) ->
      Math.max(max, j.duration)
    ), 0 )
    @averageDuration = percentile(50, success, (item) -> item.duration).duration

    {alwaysSuccess, unstable, alwaysFailed, total} = controller.statistics(jobs)

    organized = alwaysFailed.concat(alwaysSuccess).concat(unstable)

    @setItems organized

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()
    @getFilterKey = -> 'name'
    @loadingArea.append $$ @extraContent
    @handleEvents
    @loadingArea.show()

  extraContent: ->
    @div class: 'input-block-item', =>
      @button outlet: 'alwaysFailedButton', class: 'btn btn-error', 'Always Failed'
      @button outlet: 'sometimesFailedButton', class: 'btn btn-warning', 'Sometimes Failed'
      @button outlet: 'allButton', class: 'btn btn-info', 'All'

  handleEvents: =>
    @alwaysFailedButton.on 'mouseover', (e) =>
      e.preventDefault()
      @showAlwaysFailedOnly()
    @sometimesFailedButton.on 'mouseover', (e) =>
      e.preventDefault()
      @showSometimesFailedButtonOnly()
    @allButton.on 'mouseover', (e) =>
      e.preventDefault()
      @showAll()

  showAlwaysFailedOnly: ->
    {alwaysSuccess, unstable, alwaysFailed, total} = controller.statistics(jobs)
    @setItems alwaysFailed

  showSometimesFailedButtonOnly: ->
    {alwaysSuccess, unstable, alwaysFailed, total} = controller.statistics(jobs)
    @setItems unstable

  showAll: ->
    @setItems @jobs

  viewForItem: (job) ->
    type = @controller.toType(job, @averageDuration)

    artifactIcon = if job.artifacts_file then "icon gitlab-artifact" else "no-icon"
    "<li class='two-lines'>
      <div class='status status-added #{artifactIcon}'></div>
      <div class='primary-line icon gitlab-#{job.status}'>
        #{job.name}
        <i class='text-muted'> ♨︎ #{@controller.toHHMMSS(job.duration)}</i>
        <span class='pull-right text-muted'>#{job.id}</span>
      </div>
      <div class='secondary-line no-icon'>
        <div class='block'>
          <progress class='inline-block progress-#{type}' max='#{@maxDuration}' value='#{job.duration}'></progress>
        </div>
        <span class=''> #{moment(job.created_at).format('lll')}  - #{moment(job.finished_at).format('lll')} </span>
        <span class='icon icon-server'>#{job.runner?.description}</span>
        <img src='#{job.user?.avatar_url}' class='gitlab-avatar' /> #{job.user?.name}
    </li>"

  confirmed: (job) =>
    @cancel()
    if job.artifacts_file
      atom.confirm
        message: 'What to open?'
        detailedMessage: "Do you want to open the log or the report or both or all logs of the group #{job.name}?"
        buttons:
          Group: => @controller.openFailedLogsInGroup(@projectPath, @items, job)
          Log: => @controller.openLog(@projectPath, job)
          Report: => @controller.openReport(@projectPath, job)
          Both: =>
            @controller.openLog(@projectPath, job)
            @controller.openReport(@projectPath, job)
    else
      atom.confirm
        message: 'What to open?'
        detailedMessage: "Do you want to open the log or all logs of the group #{job.name}?"
        buttons:
          Group: => @controller.openFailedLogsInGroup(@projectPath, @items, job)
          Log: => @controller.openLog(@projectPath, job)

  cancelled: ->
    @panel.hide()

module.exports = JobSelectorView
