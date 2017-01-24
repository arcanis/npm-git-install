# NPM Git Install

Clone and (re)install packages from remote git repos. It is meant as a temporary solution until [npm/npm#3055][3055] is resolved.

## Installation

```sh
$> npm install --save @arcanis/npm-git-install
```

## Usage

In your `package.json`, add:

```javascript
{
  "scripts": {
    "install": "npm-git install"
  }
  "gitDependencies": {
    "private-package-name": "git@private.git.server:user/repo.git#revision?/inner/path",
    "public-package-name": "https://github.com/user/repo.git#revision?/inner/path"
  }
}
```

Don't forget to replace `*-package-name` and git URLs with values relevant to your project. URLs have to be in canonical form (i.e. one that you would provide to `git clone` on command line) - no fancy NPM shortcuts like ~~`user/repo`~~ or ~~`bitbucket:user/repo`~~. If you want this, we are open for a PRs.

Once your package.json has been updated, you can now install your dependencies as usual:

```sh
$> npm install
```

## Why

There's a serious defect in current versions of NPM (and Yarn) regarding installation process of dependencies from git repositories. It basically prevents us from installing anything that needs a build step directly from git repos. Because of that some authors are keeping build artifacts in the repos, which I would consider a hurdle at best, and contributors are sometimes hindered from using their own forks, lowering contributions. Here isthe  [relevant issue][3055], with ongoing discussion.

### TL/DR:

If you `npm install ../some-local-directory/my-package` then npm will run the `prepare` script of `my-package`, then install it in the current project. This is fine.

Now, one would expect that running `npm install git@remote-git-server:me/my-package.git` would also run `prepare` before installing, but for some reasons it won't. Even worse, it will apply `.npmignore`, which will most likely remove all your source files and make it hard to recover. Not great.

## How

### From command line

```sh
$> npm-git install
```

This simple script will do the following for every url inside the `gitDependencies` section of your `package.json` file:

1.  Clone the repository into a temporary directory.
2.  Run `npm install` in the temporary directory, which will in turn trigger the `prepare` hook of the package being installed
3.  Copy the generated module  in your project path.

In effect you will get your dependency properly installed.

You can optionally specify different paths for `package.json`:

```sh
npm-git install -c git-dependencies.json
```

You may want to do this if you find it offensive to put non-standard section in your `package.json`.

Also try `--help` for more options.

Just like with plain NPM, on the command line you can specify a space separated list of packages to be installed:

```sh
npm-git install https://github.com/someone/awesome.git me@git.server.com/me/is-also-awesome.git#experimantal-branch
```

After hash you can specify a branch name, tag or a specific commit's sha. By default `master` branch is used.

### API

You can also use it programmatically. Just require `npm-git-install`. It exposes four methods:

  * `discover (path)`

    Reads list of packages from file at given path (e.g. a package.json) and returns array of `{url, revision}` objects. You can supply this to `reinstall_all` method.

  * `reinstall_all (options, packages)`

    Executes `reinstall` in series for each package in `packages`. Options are also passed to each `reinstall` call.

    This function is curried, so if you provide just `options` argument you will get a new function that takes only one argument - `packages` array.

    Options are the same as for `reinstall`.

    Returns a `Promise` that resolves to `report`, i.e. an array of `metadata` objects:

    ```coffee-script
    [ {
      name: "my-awesome-thing"
      sha: "ef88c40"
      url: "me@git.server.com/me/my-awesome-thing.git"
    } ]
    ```

  * `reinstall (options, package)`

    Most of the heavy lifting happens here:

    1.  Clone the repo at `package.url`,
    2.  Checkout `package.revision`,
    3.  Run `npm install` inside the cloned repos directories,
    4.  Install the package from there.

    Options are:

    * `silent`: Suppress child processes standard output. Boolean. Default is `false`.
    * `verbose`: Print debug messages. Boolean. Default is `false`.

    Returns a `Promise` that will resolve to a `metadata` object:

    ```coffee-script
    {
      name: "my-awesome-thing"
      sha: "ef88c40"
      url: "me@git.server.com/me/my-awesome-thing.git"
    }
    ```

    You probably don't want to use it directly. Just call `reinstall_all` with relevant options.

If you are a [Gulp][] user, then it should be easy enough to integrate it with your gulpfile. See [./src/cli.coffee][] for example use of the API.

### Why not use `dependencies` and `devDependencies`

I tried and it's hard, because NPM supports [fancy things as Git URLs][URLs]. See `messy-auto-discovery` branch. You are welcome to take it from where I left.

There is also another reason. User may not want to reinstall all Git dependencies this way. For example I use gulp version 4, which is only available from GitHub and it is perfectly fine to install it with standard NPM. I don't want to rebuild it on my machine every time I install it. Now I can leave it in `devDependencies` and only use `npm-git-install` for stuff that needs it.

[URLs]: https://docs.npmjs.com/files/package.json#git-urls-as-dependencies
[3055]: https://github.com/npm/npm/issues/3055
[Gulp]: http://gulpjs.com/
