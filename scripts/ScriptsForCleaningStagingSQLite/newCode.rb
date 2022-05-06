## None of this is really needed
## could probably just use the manifest repo for ones to delete and keep the
## rest or manually remove additional if necessary


## https://github.com/octokit/octokit.rb/blob/4-stable/lib/octokit/client/issues.rb
## https://octokit.github.io/octokit.rb/Octokit/Client/Issues.html

require 'octokit'

Octokit::Repository.new("Bioconductor/Contributions")
Octokit.branch("Bioconductor/Contributions", "master")

Octokit.contents "Bioconductor/Contributions"



### Issues to keep 

open_issues = Octokit.list_issues(repository="Bioconductor/Contributions", per_page: 100)

inactive_issues = Octokit.list_issues(repository="Bioconductor/Contributions",
                                      state: 'closed',
                                      labels: '3c. inactive',
                                      per_page: 100)


comment = Octokit.issue_comments(repository="Bioconductor/Contributions",
                                 number=2460, per_page: 2)
description_text = comment[0][:body]
description_text.match("Package:\s*(?<pkg>[a-zA-Z_0-9\.]*)")['pkg']



## Issues to delete
accepted_issues = Octokit.list_issues(repository="Bioconductor/Contributions",
                                      state: 'closed',
                                      labels: '3a. accepted',
                                      per_page: 100)

declined_issues = Octokit.list_issues(repository="Bioconductor/Contributions",
                                      state: 'closed',
                                      labels: '3b. declined',
                                      per_page: 100)

## the above two would missed closed by user or without cause
closed_issues = Octokit.list_issues(repository="Bioconductor/Contributions",
                                      state: 'closed',
                                      per_page: 100)

