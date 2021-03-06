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
path = require 'path'
_ = require 'lodash'
yaml = require 'yaml'
matter = require 'gray-matter'
rimraf = require 'rimraf'
marked = require 'marked'
moment = require 'moment-timezone'
imageminMozjpeg = require 'imagemin-mozjpeg'
imageminPngquant = require 'imagemin-pngquant'

DATA_DIR = 'data'
PROCESSED_DATA_DIR = '.temp/data'
OUT_DIR = 'out'
CONFIG_PATH = 'config.toml'
PAGES_PATH = 'dynamic/pages'


getData = (dataPath) ->
    name = parse(dataPath).base
    id = replaceExt(name, '')
    suffix = parse(dataPath).ext
    try
        content = fs.readFileSync(dataPath, 'utf8')
    catch error
        console.log('could not read ' + dataPath)
        throw error
    data = {}

    if suffix == '.md'
        parsed = matter(content)
        data = parsed.data
        data.content = marked(parsed.content)
    
    else if suffix == '.yml'
        try
            data = yaml.parse(content)
        catch error
            console.log(error)

    else if suffix == '.toml'
        try
            data = toml.parse(content)
        catch error
            console.log(error)
    
    if data
        data.id = id
    return data

getDataObject = (dir) ->
    data = {}
    
    for name in fs.readdirSync(dir)
        if name.startsWith('_')
            continue
        dataPath = join(dir, name)
        id = replaceExt(name, '')
        id = id.split('-').join('_')
        if fs.lstatSync(dataPath).isDirectory()
            try
                data[id] = getDataObject(dataPath)
            catch e
                console.error(e)
        else
            try
                data[id] = getData(dataPath)
            catch e
                console.log(e)
    return data
   
config =

    # exec:
    #     encrypt:  'staticrypt out/articles/corona/index.html keinpasswort -o out/articles/corona/index.html'
    #     encrypt2: 'staticrypt out/projects/percy/index.html percy -o out/projects/percy/index.html'
    
    imagemin:
        main: 
            options:
                use: [imageminMozjpeg(), imageminPngquant()]
            files: [
                expand: true
                cwd: 'dynamic/images'
                src: '**/*.{png,jpg,gif}'
                dest: '.temp/images'
            ]

    responsive_images:
        options:
            newFilesOnly: true
            # createNoScaledImage: true
        's':
            options:
                sizes: [{rename: false, width: 400}]
            files: [
                expand: true
                cwd: '.temp/images'
                src: '**/*.{jpg,png,gif}'
                dest: 'out/images/s'
            ]
        'm':
            options:
                sizes: [{rename: false, width: 1000}]
            files: [
                expand: true
                cwd: '.temp/images'
                src: '**/*.{jpg,png,gif}'
                dest: 'out/images/m'
            ]
        'l':
            options:
                sizes: [{rename: false, width: 1500}]
            files: [
                expand: true
                cwd: '.temp/images'
                src: '**/*.{jpg,png,gif}'
                dest: 'out/images/l'
            ]

    'gh-pages':
        production:
            options:
                base: 'out'
            src: '**/*'
        stage:
            options:
                base: 'out'
                repo: 'git@github.com:dominiclooser/dominiclooser.ch-stage.git'
            src: '**/*'
    
    postcss:
        options:
            processors: [autoprefixer]
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
        gruntfile:
            files: 'gruntfile.coffee'
            tasks: 'build'
        scripts:
            files: 'dynamic/scripts/*'
            tasks: 'coffee'
        data:
            files: 'data/**/*'
            tasks: ['pug', 'strip-extensions']
        pages:
            files: ['dynamic/pages/*', 'dynamic/shared/*']
            tasks: ['pug', 'strip-extensions']
        styles:
            files: 'dynamic/styles/*'
            tasks: 'stylus'
        static:
            files: 'static/**/*'
            tasks: 'copy:static'
        images:
            files: 'dynamic/images/**/*'
            tasks: ['imagemin', 'responsive_images']

module.exports = (grunt) ->
    grunt.initConfig config
    time grunt
    jit grunt

    grunt.registerTask 'print-data', ->
        console.log getDataObject(PROCESSED_DATA_DIR)

    grunt.registerTask 'clean', -> 
        rimraf.sync(join(OUT_DIR, '*'))

    grunt.registerTask 'clean-data', ->
        rimraf.sync(PROCESSED_DATA_DIR)

    grunt.registerTask 'make-dirs', ->
        if !fs.existsSync(OUT_DIR)
            fs.mkdirSync(OUT_DIR)
        for name in fs.readdirSync(PAGES_PATH)
            if fs.lstatSync(path.join(PAGES_PATH, name)).isDirectory()
                outSubdir = path.join(OUT_DIR, name)
                if ! fs.existsSync(outSubdir)
                    fs.mkdirSync(outSubdir)

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
        
        globals = 
            global: getDataObject(DATA_DIR)

        globalData = getDataObject(DATA_DIR)
        
        globals = 
            global: globalData
        
        getImages = (dirId) -> 
            answer = []
            baseDir = 'dynamic/images/' + dirId
            if fs.existsSync(baseDir)
                for name in fs.readdirSync(baseDir)
                    ext = path.parse(name).ext
                    if ext in ['.jpg', '.png']
                        fileId = dirId + '/' + name
                        answer.push(fileId)
            return answer
        
        containsImages = (dirId) ->
            images = getImages(dirId)
            if images.length == 0
                return false
            else
                return true

        toWidth = (size) ->
            if size == 's'
                return 400
            else if size == 'm'
                return 1000
            else if size == 'l'
                return 1500
            else
                throw 'undefined image size'
        
        read = (filename) ->
    
            if fs.existsSync(filename)
                return fs.readFileSync(filename)
            else
                return ''    

        wikidata = {} # todo

        marked.setOptions
            smartypants: true

        globalOptions =
            basedir: 'dynamic/shared'
            base: (path) -> parse(path).base
            fs: fs
            moment: moment
            getImages: getImages
            containsImages: containsImages
            marked: marked
            toWidth: toWidth
            plugins: [{read: read}]
            wikidata: wikidata
    
            
       
        if fs.existsSync(CONFIG_PATH)
            
            configString = fs.readFileSync(CONFIG_PATH)
            try
                config = toml.parse(configString)
            catch e
                console.error(e)

            for generator in config.generators
                
                targetDirName = generator.target || ''
                targetDirPath = join(OUT_DIR, targetDirName)
                if !fs.existsSync(targetDirPath)
                    fs.mkdirSync(targetDirPath)

                templateName = generator.template || 'page.pug'

                templatePath = 'dynamic/shared/' + templateName
                templateString = fs.readFileSync(templatePath)
                parsedTemplate = matter(templateString)
                templateContent = parsedTemplate.content
                templateData = parsedTemplate.data
                
                dataGlob = generator.data

                for dataPath in glob.sync(join(DATA_DIR, dataGlob))
                    if parse(dataPath).name.startsWith('_')
                        continue
                    local = {}
                    _.merge(local, getData(dataPath), templateData)
                    locals = 
                        local: local

                    options = {}
                    _.merge(options, locals, globals, globalOptions)
                    # console.log(options)
                    process.stdout.write("Rendering #{templatePath} with data from #{dataPath} ... ")
                    try
                        html = pug.render(templateContent, options)
                    catch e
                        console.log('error.')
                        console.error(e)
                        continue
                        
                    key = parse(dataPath).base
                    
                    name = replaceExt(key, '.html')
                    targetFile = join(targetDirPath, name)
                
                    fs.writeFileSync(targetFile, html)
                    console.log("done. Generated #{targetFile}")
               
        for pagePath in glob.sync('dynamic/pages/**/*.pug')
            if parse(pagePath).name.startsWith('_')
                continue
            relativePath = path.relative(PAGES_PATH, pagePath)
            urlPath = replaceExt(relativePath, '')

            string = fs.readFileSync(pagePath)
            parsed = matter(string)
            
            options = 
                path: urlPath
            locals = 
                local: parsed.data
            _.merge(options, locals, globals, globalOptions)

            pugString = parsed.content
            
            try
                process.stdout.write("Compiling #{pagePath} ... ")
                html = pug.render(pugString, options)
            catch e
                console.log('error.')
                console.error(e)
                continue

            relativeTarget = replaceExt(relativePath, '.html')
            target = join(OUT_DIR, relativeTarget)
            console.log("done. Writing to #{target}")
            fs.writeFileSync(target, html)
            

    grunt.registerTask 'build', ['make-dirs', 'pug', 'stylus', 'postcss', 'coffee', 'copy:static', 'strip-extensions']
    grunt.registerTask 'default', ['build', 'watch']
    
    grunt.registerTask 'full_build', ['clean', 'make-dirs', 'imagemin', 'responsive_images', 'build'] 
    
    grunt.registerTask 'deploy', ['clean', 'make-dirs', 'build', 'copy:production', 'gh-pages:production']
    grunt.registerTask 'stage', ['clean-build','copy:stage', 'gh-pages:stage']