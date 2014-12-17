echo = console.log

path = require 'path'
del = require 'del'

gulp = require 'gulp'
runSequence = require 'run-sequence'
tap = require 'gulp-tap'
coffee = require 'gulp-coffee'
concat = require 'gulp-concat'
wrap = require 'gulp-wrap'
order = require 'gulp-order'
wrap = require 'gulp-wrap'
beautify = require 'gulp-beautify'
nodeunit = require 'gulp-nodeunit'

{extname} = path

basedir = __dirname
path =
  src: "#{basedir}/src"
  dist: "#{basedir}/dist"
  test: "#{basedir}/test"

wrapper =
  head: """
;(function (root, factory) {
  'use strict';

  if (typeof module === 'object' && typeof module.exports === 'object') {
    module.exports = factory();
  } else if (typeof define === 'function' && define.amd) {
    define([], factory);
  } else {
    root.Thenjs = factory();
  }
}(typeof window === 'object' ? window : this, function () {
  'use strict';

  """
  foot: """
  Thenjs.NAME = 'Thenjs';
  Thenjs.VERSION = '1.4.5';
  return Thenjs;
}));
  """

# Task Clean
gulp.task 'clean', ->
  del path.dist
  , (err, deletedFiles) ->
    echo 'Files deleted:', deletedFiles.join ', '

# Task Build
gulp.task 'build', ->
  gulp.src [
    "#{path.src}/**"
    '!**/*.uninc.coffee'
  ]
  .pipe order [
    'helper.coffee'
    'continuation.coffee'
    'then.coffee'
  ]
  .pipe concat 'then.coffee'
  .pipe coffee
    bare: true
  .pipe wrap """
  #{wrapper.head}
  <%= contents %>
  #{wrapper.foot}
  """
  .pipe beautify
    indentSize: 2
  .pipe gulp.dest path.dist

# Task Test
gulp.task 'test', ->
  gulp.src path.test
  .pipe nodeunit
    reporterOptions:
      output: 'test'

# Task Default
gulp.task 'default', ->
  runSequence 'clean', 'build', 'test'
