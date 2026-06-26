# Contributing to Biscotti CMP GTM Template

Thank you for your interest in contributing to the Biscotti CMP Google Tag Manager Community Template. This document outlines how to report issues, submit changes, and the standards we expect from contributions.

## Reporting Bugs

1. Check the [existing issues](https://github.com/dbosch-a11y/gtm-templates-biscotti-cmp/issues) to avoid duplicates.
2. Use the provided bug report template in `.github/ISSUE_TEMPLATE.md`.
3. Include the following in your report:
   - GTM container type (Web)
   - Template version (from `metadata.yaml`)
   - Steps to reproduce the issue
   - Expected vs. actual behavior
   - GTM Preview mode console output (if applicable)

## Submitting Changes

1. Fork the repository and create a feature branch from `main`.
2. Make your changes in the feature branch.
3. Ensure all unit tests in the `___TESTS___` section of `template.tpl` pass.
4. Run property-based tests with `npm test` in the `tests/` directory.
5. Submit a pull request with a clear description of the change and the problem it solves.
6. Reference any related issue numbers in the PR description.

## Code Style

- Follow Google's [GTM Community Template guidelines](https://developers.google.com/tag-platform/tag-manager/templates/gallery) for `template.tpl` structure.
- Use `const` for all variable declarations in Sandboxed JavaScript.
- Keep functions small and focused on a single responsibility.
- Add comments for non-obvious logic, especially around consent mapping.
- Use descriptive variable names (e.g., `consentUpdate` not `cu`).
- Maintain the existing section order in `template.tpl`: `___INFO___`, `___TEMPLATE_PARAMETERS___`, `___SANDBOXED_JS_FOR_WEB_TEMPLATE___`, `___WEB_PERMISSIONS___`, `___TESTS___`.

## Testing Requirements

- All changes to template logic must include corresponding unit tests in the `___TESTS___` section.
- Property-based tests in `tests/` must pass for any changes to mapping or parsing logic.
- Test both the happy path and error conditions (null localStorage, invalid JSON, missing fields).
- Verify changes in GTM Preview mode before submitting a PR.

## Contributor License Agreement (CLA)

By submitting a pull request, you agree that your contributions are licensed under the [Apache License 2.0](./LICENSE), the same license that covers this project. You confirm that you have the right to grant this license for your contributions.

## Questions?

If you have questions about contributing, open a discussion issue or reach out at [support@biscotti-cmp.com](mailto:support@biscotti-cmp.com).
