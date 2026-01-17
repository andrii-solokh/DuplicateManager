# Contributing to Duplicate Manager

Thank you for your interest in contributing to Duplicate Manager! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions. We're all here to build great software together.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up your development environment (see [Development Guide](docs/DEVELOPMENT.md))
4. Create a feature branch from `main`

## Development Workflow

### Branch Naming

- `feature/` - New features (e.g., `feature/bulk-merge`)
- `fix/` - Bug fixes (e.g., `fix/pagination-issue`)
- `docs/` - Documentation updates (e.g., `docs/api-reference`)
- `refactor/` - Code refactoring (e.g., `refactor/controller-cleanup`)

### Commit Messages

Follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat(merge): add support for custom objects`
- `fix(viewer): resolve pagination offset issue`
- `docs(readme): update installation instructions`

## Code Standards

### Apex

- Follow [Salesforce Apex Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_intro_what_is_apex.htm)
- Use `with sharing` unless there's a documented reason not to
- Include ApexDoc comments for all public methods
- Maintain >80% code coverage with meaningful assertions
- Use `Assert.areEquals` instead of `System.assert`

### Lightning Web Components

- Follow [LWC Best Practices](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.get_started_best_practices)
- Use `@track` only when necessary (arrays/objects that need reactivity)
- Handle all error states gracefully
- Include loading states for async operations
- Use CSS custom properties for theming

### General

- No hardcoded IDs or org-specific values
- Keep methods focused and under 50 lines when possible
- Add meaningful comments for complex logic
- Remove console.log statements before committing

## Testing

### Running Tests

```bash
# Run all Apex tests
sf apex run test --target-org your-scratch-org --test-level RunLocalTests --code-coverage

# Run LWC Jest tests
npm run test:unit

# Run with coverage
npm run test:unit:coverage
```

### Test Requirements

- All new Apex code must have >80% coverage
- All new LWC code must have Jest tests
- Tests should include positive, negative, and edge cases
- Use descriptive test method names

## Pull Request Process

1. **Update documentation** if you've changed APIs or added features
2. **Add tests** for any new functionality
3. **Run all tests** locally and ensure they pass
4. **Update CHANGELOG.md** with your changes under `[Unreleased]`
5. **Create a pull request** with a clear description of:
   - What changes were made
   - Why the changes were needed
   - How to test the changes

### PR Review Checklist

- [ ] Code follows project standards
- [ ] Tests pass and coverage is maintained
- [ ] Documentation is updated
- [ ] CHANGELOG is updated
- [ ] No merge conflicts
- [ ] Commits are squashed/cleaned up

## Reporting Issues

When reporting issues, please include:

1. **Description** - Clear description of the issue
2. **Steps to Reproduce** - How to recreate the issue
3. **Expected Behavior** - What should happen
4. **Actual Behavior** - What actually happens
5. **Environment** - Salesforce edition, API version, browser
6. **Screenshots** - If applicable

## Feature Requests

We welcome feature requests! Please include:

1. **Use Case** - Why is this feature needed?
2. **Proposed Solution** - How should it work?
3. **Alternatives Considered** - Other approaches you've thought about

## Questions?

Feel free to open an issue with the `question` label if you have questions about contributing.

Thank you for contributing! 🎉
