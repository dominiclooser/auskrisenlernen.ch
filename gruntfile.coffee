time = require 'time-grunt'
jit = require 'jit-grunt'
autoprefixer = require 'autoprefixer'
cssVariables = require 'postcss-css-variables'
calc = require 'postcss-calc'
fs = require 'fs'
glob = require 'glob'
toml = require 'toml'
pug = require 'pug'
replaceExt = require 'replace-ext'
{ join, parse } = require 'path'
_ = require 'lodash'
yaml = require 'yaml'
matter = require 'gray-matter'
rimraf = require 'rimraf'
marked = require 'marked'

DATA_DIR = 'data'
OUT_DIR = 'out'
CONFIG_PATH = 'config.toml'

get_data = (path) ->
    suffix = parse(path).ext
    if suffix == '.md'
        string = fs.readFileSync(path, 'utf8')
        parsed = matter(string)
        data = parsed.data
        data.content = marked(parsed.content)
        return data


get_data_object = (dir) ->
    data = {}
   
    data.md2html = marked
    
    for name in fs.readdirSync(dir)
        path = join(dir, name)
        if fs.lstatSync(path).isDirectory()
            data[name] = get_data_object(path)

    for path in glob.sync(join(dir, '*.md'))
        string = fs.readFileSync(path, 'utf8')
        parsed = matter(string)
        locals = parsed.data
        locals.content = marked(parsed.content)
        name = parse(path).base
        id = replaceExt(name, '')
        data[id] = locals

    for filePath in glob.sync(dir + '/*.toml')
        string = fs.readFileSync(filePath, 'utf8')
        fileData = toml.parse(string)
        fileName = parse(filePath).base
        id = replaceExt(fileName, '')
        data[id] = fileData

    for path in glob.sync(dir + '/*.yml')
        string = fs.readFileSync(path, 'utf8')
        fileData = yaml.parse(string)
        name = parse(path).base
        id = replaceExt(name, '')
        data[id] = fileData
        
    return data
   
config =
    responsive_images:
        options:
            engine: 'im'
            newFilesOnly: true
        's':
            options:
                sizes: [{rename: false, width: 400}]
            files: [
                    expand: true
                    cwd: 'dynamic/images'
                    src: '**/*.{jpg, png}'
                    dest: 'out/images/s'
            ]
        'm':
            options:
                sizes: [{rename: false, width: 1000}]
            files: [
                    expand: true
                    cwd: 'dynamic/images'
                    src: '**/*.{jpg, png}'
                    dest: 'out/images/m'
            ]
    'gh-pages':
        production:
            options:
                base: 'www'
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
            src: 'out/styles/styles.css'
    copy:
        static:
            cwd: 'static'
            src: '**/*'
            expand: true
            dest: 'out' 
        'production':
            src: 'cnames/production'
            dest: 'out/CNAME'
        'stage':
            src: 'cnames/stage'
            dest: 'out/CNAME'
    coffee:
        main:
            expand: true
            flatten: true
            ext: '.js'
            src: 'dynamic/scripts/*.coffee'
            dest: 'out/scripts/'
    stylus:
        main:
            src: 'dynamic/styles/styles.styl'
            dest: 'out/styles/styles.css'  
    watch:
        scripts:
            files: 'dynamic/scripts/*'
            tasks: 'coffee'
        pages:
            files: ['dynamic/pages/*', 'dynamic/shared/*', 'data/**/*']
            tasks: ['pug', 'strip-extensions']
        styles:
            files: 'dynamic/styles/*'
            tasks: 'stylus'
        static:
            files: 'static/**/*'
            tasks: 'copy:static'
        images:
            files: 'dynamic/images'
            tasks: 'responsive_images'

module.exports = (grunt) ->
    grunt.initConfig config
    time grunt
    jit grunt

    grunt.registerTask 'clean', -> 
        rimraf.sync(join(OUT_DIR, '*'))

    grunt.registerTask 'make-dirs', ->
        if !fs.existsSync(OUT_DIR)
            fs.mkdirSync(OUT_DIR)

    grunt.registerTask 'strip-extensions', ->
        for filePath in glob.sync('out/**/*.html')
            parsedPath = parse(filePath)
            name = parsedPath.name
            if name != 'index'
                dir = parsedPath.dir
                newDir = dir + '/' + name
                if !fs.existsSync(newDir)
                    fs.mkdirSync(newDir)
                fs.renameSync(filePath, newDir + '/index.html')
    
    grunt.registerTask 'pug', ->
        globals = get_data_object(DATA_DIR)
        globalOptions =
            basedir: 'dynamic/shared'
            base: (path) -> parse(path).base
        
        if fs.existsSync(CONFIG_PATH)
            
            configString = fs.readFileSync(CONFIG_PATH)
            config = toml.parse(configString)
            
            for generator in config.generator
                
                targetDirName = generator.target || ''
                targetDirPath = join(OUT_DIR, targetDirName)
                if !fs.existsSync(targetDirPath)
                    fs.mkdirSync(targetDirPath)

                templatePath = 'dynamic/shared/' + generator.template
                dataGlob = generator.data

                for path in glob.sync(join(DATA_DIR, dataGlob))
                    
                    locals = get_data(path)
                    
                    options = {}
                    _.merge(options, locals, globals, globalOptions)
                    
                    html = pug.renderFile(templatePath, options)
                    key = parse(path).base
                    
                    name = replaceExt(key, '.html')
                    targetFile = join(targetDirPath, name)
                
                    fs.writeFileSync(targetFile, html)
        
        for path in glob.sync('dynamic/pages/*.pug')
            string = fs.readFileSync(path)
            parsed = matter(string)
            options = {}
            _.merge(options, parsed.data, globals, globalOptions)
            pugString = parsed.content
            html = pug.render(pugString, options)
        
            base = parse(path).base
            target = join(OUT_DIR, replaceExt(base, '.html'))
           
            fs.writeFileSync(target, html)

    grunt.registerTask 'build', ['pug', 'stylus', 'coffee', 'copy:static', 'strip-extensions']
    grunt.registerTask 'default', ['clean', 'make-dirs', 'build', 'watch']
    grunt.registerTask 'deploy', ['clean-build','copy:production', 'gh-pages:production']
    grunt.registerTask 'stage', ['clean-build','copy:stage', 'gh-pages:stage']