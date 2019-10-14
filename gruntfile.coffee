time = require 'time-grunt'
jit = require 'jit-grunt'
autoprefixer = require 'autoprefixer'
cssVariables = require 'postcss-css-variables'
calc = require 'postcss-calc'
fs = require 'fs'
glob = require 'glob'


config =
    pug:
        options:
            basedir: 'shared'
        main:
            cwd: 'pages'
            src: '*.pug'
            expand: true
            dest: 'out'
            ext: '.html'

    responsive_images:
        options:
            engine: 'im'
            newFilesOnly: true
        's':
            options:
                sizes: [{rename: false, width: 400}]
            files: [
                    expand: true
                    cwd: 'raw'
                    src: '**/*.{jpg,png}'
                    dest: 'images/s'
            ]
        'm':
            options:
                sizes: [{rename: false, width: 1000}]
            files: [
                    expand: true
                    cwd: 'raw'
                    src: '**/*.{jpg,png}'
                    dest: 'images/m'
            ]

    'gh-pages':
        production:
            options:
                base: 'out'
            src: '**/*'
        stage:
            options:
                base: 'www'
                repo: 'git@github.com:dominiclooser/dominiclooser.ch-stage.git'
            src: '**/*'

    postcss:
        options:
            processors: [autoprefixer({browers: 'last 2 versions'}), cssVariables, calc]
        main:
            src: 'www/styles/styles.css'

    copy:
        assets:
            src: ['images/**/*', 'scripts/*.js', 'favicon.ico', 'fonts/*', 'videos/*.*', 'documents/*']
            expand: true
            dest: 'out' 
        'production':
            src: 'cnames/production'
            dest: 'www/CNAME'
        'stage':
            src: 'cnames/stage'
            dest: 'www/CNAME'

    coffee:
        main:
            expand: true
            flatten: true
            ext: '.js'
            src: 'public/scripts/*.coffee'
            dest: 'www/scripts/'

    stylus:
        main:
            src: 'styles/styles.styl'
            dest: 'out/styles.css'

    yaml:
        main:
            expand: true
            src: ['harp.yml', 'public/**/_data.yml']
            ext: '.json'
            
    watch:
        pug:
            files: ['pages/*', 'shared/*']
            tasks: 'pug'
        styles:
            files: 'styles/*'
            tasks: 'stylus'
        assets:
            files: ['fonts/*', 'images/**/*', 'documents/*']
            tasks: 'copy:assets'
        images:
            files: 'raw/**/*'
            tasks: 'responsive_images'

module.exports = (grunt) ->
    grunt.initConfig config
    time grunt
    jit grunt
    
    grunt.registerTask 'ext', ->
        for file in glob.sync('out/*.html')
            data = fs.readFileSync(file)
            grunt.log.writeln(data)

    grunt.registerTask 'build', ['pug', 'stylus', 'copy']
    grunt.registerTask 'default', ['build', 'watch'] 
    grunt.registerTask 'deploy', ['build', 'gh-pages:production']
    # grunt.registerTask 'stage', ['build','copy:stage', 'gh-pages:stage']