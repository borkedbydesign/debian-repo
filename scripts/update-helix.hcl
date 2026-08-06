workflow "update_github_version" {
  description = "Checks for latest gihthub version and updates if newer"

  variable "version_repo" {
    default = "helix-editor/helix"
  }

  variable "version_file" {
    default = "./packages/helix.json"
  }

  variable "gh_token" {}

  step "open_version_file" {
    type = "load_file"
    description = "Loads the version JSON file"
    location = var.version_file
    output = "file"
  }

  step "read_version_file_json" {
    depends_on = ["open_version_file"]
    type = "json_extract"
    description = "Read the JSON version file"
    input = steps.open_version_file.file.body
    path = "$.version"
    output = "version"
  }

   step "github_release_api" {
    type = "api_request"
    description = ""
    url = "https://api.github.com/repos/${var.version_repo}/releases/latest"
    method = "GET"
    output = "response"  
  }

  step "read_github_version_json" {
    depends_on = ["github_release_api"]
    type = "json_extract"
    description = ""
    input = steps.github_release_api.response.body
    path = "$.tag_name"
    output = "version"
  }

  step "update_version_json" {
    description = ""
    depends_on = ["read_github_version_json", "read_version_file_json"]
    when = steps.read_github_version_json.version != steps.read_version_file_json.version
    type = "write_file"
    content = jsonencode({
      version = steps.read_github_version_json.version
    })
    location = var.version_file
    output = "write"
  }

  step "git_add_files" {
    depends_on = ["update_version_json"]
    type = "shell"
    command = "git add ./packages/helix.json"
    output = "stdout"
    description = ""
  }

   step "git_create_branch" {
    depends_on = ["git_add_files"]
    type = "shell"
    command = "git checkout -b 'helix-${steps.read_github_version_json.version}'"
    output = "stdout"
    description = "" 
  }

  step "git_commit_changes" {
    depends_on = ["git_create_branch"]
    type = "shell"
    command = "git -c user.name='Version Robot' -c user.email='robot@borkedbydesign.net' commit -m 'Upgrade helix to ${steps.read_github_version_json.version}'"
    output = "stdout"
    description = "" 
  }

  step "git_push" {
    depends_on = ["git_commit_changes"]
    type = "shell"
    command = "git push --set-upstream origin helix-${steps.read_github_version_json.version}"
    output = "stdout"
    description = ""
  }

  step "github_open_pr" {
    depends_on = ["git_push"]
    type = "api_request"
    description = ""
    headers = {
      Accept = "application/vnd.github+json",
      Authorization = "Bearer ${var.gh_token}"
      X-GitHub-Api-Version = "2026-03-10"
    }
    body = jsonencode({
      "title": "Updates Helix to ${steps.read_github_version_json.version}"
      "body": "Updates Helix to ${steps.read_github_version_json.version}"
      "head": "helix-${steps.read_github_version_json.version}"
      "base": "main"
    })
    url = "https://api.github.com/repos/${var.version_repo}/releases/latest"
    method = "POST"
    output = "response"  
  }
}
