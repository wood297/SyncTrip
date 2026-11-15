# SyncTrip Team Development Process

## 1. Repository Architecture

```text
SyncTrip/
├── ios/
│   ├── App/
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   ├── Resources/
│   └── SyncTrip.xcodeproj/
├── backend/
│   ├── routes/
│   ├── models/
│   ├── services/
│   ├── database/
│   └── main.py
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── system/
│   ├── sync/
│   └── swift/
├── scripts/
├── doc/
│   ├── GUIDELINES.md
│   ├── architecture.md
│   ├── AGENTS.md
│   └── api.md
├── .github/
│   ├── workflows/
│   └── PULL_REQUEST_TEMPLATE.md
├── .gitignore
└── README.md
```

| Location | Purpose |
| --- | --- |
| `ios/` | SwiftUI entry point, data models, screens, view state, API client, and assets. |
| `backend/` | FastAPI routes, data validation, application logic, and DynamoDB access. |
| `tests/` | Unit, integration, system, peer sync, and Swift tests. |
| `scripts/` | Tools to verify the running API. |
| `doc/` | Development process, architecture, API reference, and project documents. |
| `.github/` | CI workflows and the pull request template. |
| `.gitignore` | Rules for excluding local environments and generated files. |
| `README.md` | Setup, run, and test instructions. |

We separate SwiftUI screens from observable state so data changes can update the views that use them. [Apple’s SwiftUI model data guide](https://developer.apple.com/documentation/swiftui/model-data)
We organize the API into route modules using `APIRouter` and register them in the application entry point. [FastAPI’s guide to larger applications](https://fastapi.tiangolo.com/tutorial/bigger-applications/)

## 2. Branching and Workflow

`main` holds the shared, reviewed prototype. Each teammate starts from the latest `main` and creates a branch in the shared repository without making a personal fork. Use lowercase names with hyphens, such as `feature/activity-form` for new work, `bugfixes/day-plan-full-screen-form` for fixes, `docs/demo-trip-configuration` for documentation, and `integration/activity-flow` when related changes need to be tested together. Develop and test on your branch, then push it and open a pull request into `main` or an agreed integration branch. [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow)

## 3. Code Development and Review Policy

Open a focused pull request for every feature or fix, aiming for one or two per week during active development. Use the PR template to describe the change, report test results, and link the documentation updated with the PR. Request at least one teammate review and aim to respond to review requests within 48 hours. The PR author addresses feedback, resolves merge conflicts, and reruns affected checks. Before merging into `main` or a shared integration branch, get at least one teammate approval and confirm the applicable CI checks pass. GitHub Actions runs backend, API, sync, and Swift checks plus an iOS simulator build, and runs again when changes land on `main`. Check that run after merging and open a focused fix or revert PR if it fails.
