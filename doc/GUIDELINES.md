Repository Architecture

SyncTrip/
├── ios/                 # iOS application
│   ├── App/             # App entry point
│   ├── Models/          # Data models
│   ├── Views/           # User interface
│   ├── ViewModels/      # UI state and logic
│   ├── Services/        # API and sync communication
│   └── Resources/       # Images and assets
│
├── backend/             # Backend application
│   ├── routes/          # API endpoints
│   ├── models/          # Data structures
│   ├── services/        # Business logic
│   └── database/        # Database access
│
├── tests/
│   ├──unit/         # Unit tests
│   ├──system/         # System tests
│   ├── integration/     # Cross-component tests
│   └── sync/            # Offline/sync tests
│
├── doc/                 # Project documentation
│   ├── GUIDELINES.md
│   ├── architecture.md
│   ├── AGENTS.md
│   └── api.md
│
├── .github/
│   ├── workflows/       # GitHub Actions CI
│   └── PULL_REQUEST_TEMPLATE.md
│
├── .gitignore
└── README.md



Branching / Workflow Model

Main
feature/

integration/
docs/
bugfixes/

Workflow:
    1.  Create a feature branch from main
    2.  Develop and test on that branch
    3.  Push changes and open pull request
    4.  One teammate reviews / adds comments
    5.  Address comments then merge


Code Development & Review Policy

-Everyone has to open a PR
-At least 1 approval from a teammate
-review within 48 hours of a request
-smaller PRs (one feature, one bug fix, etc)
-set up automated tests, test on merge
-merge conflict - whoever has the PR fixes the conflict
-update documentation for every PR
-PR for every feature/fix, likely 1-2 times a week