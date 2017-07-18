# Atom gitlab-integration package

Track gitlab pipelines state of your project.

![Screenshot](https://user-images.githubusercontent.com/1149069/28337289-7973ebcc-6c05-11e7-844d-c7a1e106317c.png)

# Configuration

 - Once installed, fill your Gitlab API token in the package's settings page
   - If you don't know what they are, please refer to https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html,
   - `gitlab-integration` requires **api** access
 - Clone a project hosted on a gitlab server
   - **warning** pay attention to the URL you use to clone your project. Indeed, `gitlab-integration` uses origin URL to determine where to reach Gitlab API to get pipeline statuses.
 - Add the project to Atom or directly open a file from your project
 - `gitlab-integration` should display pipeline statuses in the status bar if it can correctly determine and reach the gitlab server where your project is hosted like shown above.
 - *In case any errors occurs, a message should be logged in Atom developer console.*

# Contributing
Reporting issues and pull requests are more than welcome on this project.
