## `dependabot-dependency-services`

Support for package managers using `dependency_services` in
[`dependabot-core`][core-repo].

### Running locally

1. Install Ruby dependencies
   ```
   $ bundle install
   ```

2. Run tests
   ```
   $ bundle exec rspec spec
   ```

[core-repo]: https://github.com/dependabot/dependabot-core

## Dependency Services

This document outlines definitions and CLI interface that should be implemented
for dependabot integration of new package management ecosystem. The interface
can be implemented directly by a package manager or by a wrapper script.

The aim of this document is to ease dependabot integration of new
package managers, by allowing package managers to directly implement features
required for dependabot support.

**STATUS:** Draft, this might just end up being a useful discussion to help
understand how to make dependabot integration for Dart.

### Assumptions

 * Each dependency has a unique name that can be represented as a string.
    * Example: package name or url.
    * Needs to be unique within the given project.
 * Each version has a unique identifer that can be represented as a string.
    * Example: version number, revision hash.
    * Needs to be unique for a given dependency.

### List Dependencies

```js
# dependency_services capabilites
{
  "list": {
    "unpublished": true,
    "advisories": true,
  },
  "report": {
    "patch": true,
    "compatible": true,
    "single-breaking": true,
    "multi-breaking": true,
  },
  "apply": {
    "changes": true,
  },

  // Files that should be in working-folder when dependency_services is used.
  // null, if the entire project repository should be cloned.
  "requiredFiles": [
    "<manifest>",
    ...,
  ] || null,
  "optionalFiles": [
    "<lock-file>",
    ...,
  ] || null,
}
```

### List Dependencies

```js
# dependency_services list
{
  "dependencies": [
    // For each dependency:
    {
      // Unique identifer for a dependency.
      //
      // Typically a package name, or maybe a URL, or git-url, must be
      // human-readable.
      //
      // This must be unique within a given project. That is in two different
      // projects the {"name": "foo", ...} may refer to two different
      // dependencies.
      "name": "<package-name>",

      // Unique identifier for the current version of this dependency.
      //
      // Typically a version number, or maybe a git revision hash.
      "version": "<version>",

      // The dependency kind.
      "kind": "direct" || "dev" || "transitive",
    },
    ... // must contain an entry for each dependency!
  ],
}
```

### Dependency Report

```js
# dependency_services report
{
  "dependencies": [
    // For each dependency:
    {
      // Same as in list-dependencies:
      "name":     "<package-name>", // name of current dependency
      "version":  "<version>",      // current version
      "kind":     "direct" || "dev" || "transitive",

      // Is the current dependency retracted, yanked, unpublished or deleted?
      "unpublished": true | false,
      
      // List of security advisories for the current version
      "advisories": [
        {
          "name": "<identifier>", // used when making links
          "url":  "https://...",
          "versions": [
            "<version>",
            "<version>",
            ...
          ],
        },
        ...
      ],

      // Latest version of the current dependency, ignoring pre-releases.
      "latest": "<version>",

      // If the current version is unpublished or has an applicable advisory
      // this section lists changes necessary to avoid advisories and
      // unpublished versions.
      //
      // The set of changes here should aim to avoid unnecessary changes.
      // That is in order of preference (heuristics allowed):
      //  * Change current dependency to a version without an advisory,
      //  * Avoid changes to the project manifest when possible,
      //  * Remove unnecessary transitive dependencies,
      //  * Avoid changing transitive dependencies when possible,
      //  * Avoid jumping more versions than necessary,
      //  * Avoid downgrading the current dependency when possible.
      //
      // This may change multiple dependencies, it may involve breaking version
      // changes, but should aim to make as small a change as possible, so that
      // the likelihood this change can be successfully merged is high.
      //
      // If the current version is not unpublished and there is no advisories
      // for the current version, then this is simply an empty list as there is
      // no version patching to be done.
      "patch": [
        {"name": "<package-name>", "version": "<new-version>"},
        {"name": "<package-name>", "version": null /* package removed */ },
        ...
      ],

      // If it is possible to upgrade the current version without making any
      // changes in the project manifest, then this lists the set of upgrades
      // necessary to get the latest possible version of the current dependency
      // without changes to project manifest.
      //
      // The set of changes here should aim to avoid unnecessary changes.
      // That is in order of preference (heuristics allowed):
      //  * Always avoid any changes to project manifest,
      //  * Upgrade current dependency to latest version possible,
      //  * Remove unnecessary transitive dependencies,
      //  * Avoid changes to other dependencies when possible.
      //
      // This can involve breaking version changes for transitive dependencies.
      // But breaking changes for direct-dependencies is only possible if the
      // manifest allows this.
      "compatible": [
        {"name": "<package-name>", "version": "<new-version>"},
        {"name": "<package-name>", "version": null /* package removed */ },
        ...
      ],

      // If it is possible to upgrade the current version without making changes
      // to other dependencies in the project manifest, then this lists the set
      // of upgrades necessary to get the latest possible version of the current
      // dependency without changes to other packages in project manifest.
      //
      // The set of changes here should aim to avoid unnecessary changes.
      // That is in order of preference (heuristics allowed):
      //  * Always avoid changes to other dependencies in project manifest,
      //  * Upgrade the current dependency to latest version possible,
      //  * Remove unnecessary transitive dependencies,
      //  * Avoid changes to other dependencies when possible.
      //
      // This can involve breaking version changes for the current dependency.
      // It can also involve breaking changes for transitive dependencies. But
      // breaking changes for direct-dependencies is only possible if the
      // manifest allows this.
      "single-breaking": [
        {"name": "<package-name>", "version": "<new-version>"},
        {"name": "<package-name>", "version": null /* package removed */ },
        ...
      ],

      // If it is possible to upgrade the current version of the current
      // dependency by allowing multiple changes project manifest, then this
      // lists the set of upgrades necessary to get the latest possible version
      // of the current dependency, without removing any direct-dependencies.
      //
      // The set of changes here should aim to avoid unnecessary changes.
      // That is in order of preference (heuristics allowed):
      //  * Always avoid removing direct-/dev-dependencies from project manifest.
      //  * Upgrade the current dependency to latest version possible,
      //  * Avoid changes to other dependencies in project manifest when
      //    possible,
      //  * Remove unnecessary transitive dependencies,
      //  * Avoid changes to other dependencies when possible.
      //
      // This can involve breaking changes for any dependency.
      "multi-breaking": [
        {"name": "<package-name>", "version": "<new-version>"},
        {"name": "<package-name>", "version": null /* package removed */ },
        ...
      ],
    },
    ... // must contain an entry for each dependency!
  ],
}
```

### Applying Changes

This does the minimal changes necessary to reach the `<package>:<version>`
parameters given.

```js
# dependency_services apply <package>:<version> ... \
{
  "dependencies": [
    // For each dependency: (even ones not changed)
    {
      // Same as in list-dependencies:
      "name":     "<package-name>",     // name of current dependency
      "version":  "<version>" || null,  // current version, null if removed!
      "kind":     "direct" || "dev" || "transitive",

      // What was the previous version, same as "version" if no change!
      "previous": "<version>",

      // Link to changelog
      "changelog": "https://...",

      // List of changelog entries from "version" to "previous" version.
      "changes": [
        {
          "version": "<version>",
          "section": "<markdown>",
        },
        ...
      ],

      // TODO: other meta-data fields like something to find commits...
    },
    ... // must contain an entry for each dependency!
  ],
}
```

### Registration of `dependency-services`

```js
// dependency-services.json
{
  "packageManagers": [ 
    {
      // Name of package manager
      "name": "<name>",
      
      // Command for dependency-services
      "command": [
        "/path/to/dart-sdk",
        "dart",
        "pub",
        "__dependency-services",
      ],
    },
  ],
}
```
