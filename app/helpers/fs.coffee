module.exports = (helpers, cfg, log) ->
  async = require 'async'
  fs = require 'fs-extra'

  class FileSystemHelper
    @traverseDir = (dirpath, callback) ->
      async.waterfall [
        # List dirpaths items
        (next_step) ->
          fs.readdir dirpath, next_step

        # Retrieve all files' stats
        (files, next_step) ->
          async.map files
            , (item, next_file) ->
              fs.lstat "#{dirpath}/#{item}", (err, stat) ->
                if stat?
                  stat.path = "#{dirpath}/#{item}"
                else
                  stat = {}

                next_file err, stat
            , next_step

        # Create the files' paths array
        (files_stats, next_step) ->
          async.map files_stats
            , (item, next_file) ->
              if item.isFile()
                next_file null, item.path
              else if item.isDirectory()
                helpers.fs.traverseDir item.path, next_file
            , next_step
      ], (err, files_paths) ->
        callback err, files_paths?.flatten()

    @traverseDirSync = (dirpath) ->
      files = []

      for item in fs.readdirSync dirpath
        stat = fs.lstatSync "#{dirpath}/#{item}"

        if stat.isDirectory()
          files.push @traverseDirSync "#{dirpath}/#{item}"
        else if stat.isFile()
          files.push "#{dirpath}/#{item}"

      return files.flatten()

  # We make helpers.fs be magical
  return Object.merge fs, FileSystemHelper