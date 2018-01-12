{$, $$, SelectListView} = require 'atom-space-pen-views'
moment = require 'moment'
# moment.locale('sk')
class JobSelectorView extends SelectListView
  toHHMMSS: (sec_num) ->
    sec_num = Math.round(sec_num)
    hours = Math.floor(sec_num / 3600)
    minutes = Math.floor((sec_num - (hours * 3600)) / 60)
    seconds = sec_num - (hours * 3600) - (minutes * 60)
    if hours < 10
      hours = "0"+hours
    if minutes < 10
      minutes = "0"+minutes
    if seconds < 10
      seconds = "0"+seconds
    if hours is "00"
      "#{minutes}m #{seconds}s"
    else
      "#{hours}h #{minutes}m #{seconds}s"

  initialize: (jobs, controller, projectPath) ->
    super

    @controller = controller
    @projectPath = projectPath
    @addClass('overlay from-top')

    jobs?.sort (a, b) ->
      return -1 if a.name < b.name
      return 1 if a.name > b.name
      return -1 if a.id < b.id
      return 1 if a.id > b.id
      return 0

    @setItems jobs

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()
    @getFilterKey = -> 'name'
    @loadingArea.append $$ @extraContent
    @handleEvents
    # @loadingArea.show()

  extraContent: ->
    @div class: 'block', =>
      @div class: 'input-block-item', =>
        @button outlet: 'totalButton', class: 'btn btn-info', 'Total failures'


  handleEvents: =>
    @totalButton.on 'click', => @totalFailures()

  totalFailures: ->
    @setItems @controller.totalFailed @items

  viewForItem: (job) ->
    artifactIcon = if job.artifacts_file then "icon gitlab-artifact" else "no-icon"
    "<li class='two-lines'>
      <div class='status status-added #{artifactIcon}'></div>
      <div class='primary-line icon gitlab-#{job.status}'>
        #{job.name}
        <i class='text-muted'> ♨︎ #{@toHHMMSS(job.duration)}</i>
        <span class='pull-right text-muted'>#{job.id}</span>
      </div>
      <div class='secondary-line no-icon'>
        <span class=''> #{moment(job.finished_at).format('lll')} </span>
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
