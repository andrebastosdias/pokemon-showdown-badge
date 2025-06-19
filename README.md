# Generate Contribution Badges

Generates contributor, commits, open PRs, and last commit badges for a given user + repo.

## Inputs

- `user` (required): GitHub username
- `repository` (optional): `owner/repo` (defaults to current)
- `colors` (optional): comma-separated badge colors, default `"F34134,8334B7,00A398,004878"`

## Example Workflow

```yaml
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'

jobs:
  badges:
    runs-on: ubuntu-latest
    steps:
      - uses: andrebastosdias/generate-contribution-badges@v1
        with:
          user: 'andrebastosdias'
          repository: 'smogon/pokemon-showdown'
          colors: 'gold,blue,green,orange'
```
