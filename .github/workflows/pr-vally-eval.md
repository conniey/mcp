name: Pull Request vally evaluations
description: |
  Evaluates E2E prompts to ensure they still pass when tools are changed.

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - 'tools/**'
      - 'core/Microsoft.Mcp.Core/**'
      - '.vally.yaml'
permissions:
  copilot-requests: write
  contents: read
  pull-requests: read
engine: copilot
network:
  allowed:
    - defaults
    - github
    - node
tools:
  github:
    toolsets: [default]
safe-outputs:
  add-comment:
  create-pull-request-review-comment:

jobs:
  eval-job:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7.0.0

      - name: Install .NET SDK
        uses: actions/setup-dotnet@v5.4.0

      - name: Create build_info.json
        shell: pwsh
        run: ./eng/scripts/New-BuildInfo.ps1 -ServerName Azure.Mcp.Server -CI

      - name: Run vally e2e evaluations
        run: dotnet build --project ./eng/tools/VallyEvaluator/VallyEvaluator.csproj
      
      - name: List evaluations
        run: ls -R ./.work/evals/
