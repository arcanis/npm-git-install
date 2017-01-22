cp          = require 'child_process'
temp        = require 'temp'
fs          = require 'fs'
{ resolve } = require 'path'

{
  cwd
  chdir
}         = process

# Helpful promises
exec = (cmd, options) -> new Promise (resolve, reject) ->
  [ cmd, args... ] = cmd.split ' '
  child = cp.spawn cmd, args, options
  child.on 'close', (code) ->
    if code is 0 then resolve code
    else reject code

mktmp = (prefix) -> new Promise (resolve, reject) ->
  temp.mkdir prefix, (error, path) ->
    if error then return reject error
    resolve path


reinstall = (options = {}, pkg) ->
  {
    silent
    verbose
  } = options

  curried = ({ url, revision, path }) ->
    do temp.track

    tmp = null

    name = null
    sha = revision

    stdio = [
      'pipe'
      if silent then 'pipe' else process.stdout
      process.stderr
    ]

    mktmp 'npm-git-'
      .then (path) ->
        tmp = path

      .then ->
        github = url.match /^git@github.com:([^\/]+?)\/([^\/]+?)$/ or url.match /^https:\/\/github.com\/([^\/]+?)\/([^\/]+?).git$/

        if github

          cmd = "curl https://api.github.com/repos/#{github[1]}/#{github[2]}/tarball/#{revision} | tar xz"
          if verbose then console.log "Downloading '#{url}' into #{path}"

          exec cmd, { cwd: tmp, stdio }

        else

          cmd = "git clone #{url} #{tmp}"
          if verbose then console.log "Cloning '#{url}' into #{tmp}"

          exec cmd, { cwd: tmp, stdio }

          .then ->
            cmd = "git checkout #{revision}"
            if verbose then console.log "Checking out #{revision}"

            exec cmd, { url, cwd: tmp, stdio }

          .then ->
            cmd = "git show --format=format:%h --no-patch"
            if verbose then console.log "Executing `#{cmd}` in `#{tmp}`"

            sha = cp
              .execSync cmd, { cwd: tmp }
              .toString "utf-8"
              .trim()

      .then ->
        pkginfo = require "#{tmp}/package.json"
        name = pkginfo.name

      .then ->
        cmd = 'npm install'
        if verbose then console.log "Executing `#{cmd}` in `#{tmp}`"

        exec cmd, { cwd: "#{tmp}/#{path}", stdio }

      .then ->
        cmd = "npm install #{tmp}/#{path}"
        if verbose then console.log "Executing `#{cmd}` in the current directory"

        exec cmd, { stdio }

        return {
          name
          url
          sha
        }

  return if pkg then curried pkg else curried

discover = (package_json = '../package.json') ->
  package_json = resolve package_json
  delete require.cache[package_json]
  { gitDependencies } = require package_json
  ( url for name, url of gitDependencies)

save = (file = '../package.json', report) ->
  file = resolve file
  delete require.cache[file]
  pkg = require file
  pkg.gitDependencies ?= {}
  for { name, url, sha } in report
    do (name, url, sha) -> pkg.gitDependencies[name] = "#{url}##{sha}"

  fs.writeFileSync file, JSON.stringify pkg, null, 2

###

As seen on http://pouchdb.com/2015/05/18/we-have-a-problem-with-promises.html

###

reinstall_all = (options = {}, packages) ->

  curried = (packages) ->
    factories = packages.map (url) ->
      [ whole, url, revision, path ] = url.match ///
        ^
        (.+?)        # url
        (?:\#(.+?))? # revision
        (?:\?(.+?))? # path
        $
      ///
      revision ?= 'master'
      path ?= ''

      return (memo) ->
        Promise
          .resolve reinstall options, { url, revision, path }
          .then (metadata) ->
            memo.concat metadata

    sequence = Promise.resolve []
    for factory in factories
      sequence = sequence.then factory

    return sequence

  return if packages then curried packages else curried


module.exports = {
  discover
  reinstall
  reinstall_all
  save
}
