require! 'dcs/lib/keypath': {get-keypath, set-keypath}
require! '../../kernel': {PaperDraw}
require! './get-aecad': {get-aecad}
require! 'aea': {merge}
require! './lib': {prefix-keypath}
require! './component-manager': {ComponentManager}


# Basic methods that every component should have
# -----------------------------------------------
export class ComponentBase
    (data) ->
        @scope = new PaperDraw
        @ractive = @scope.ractive
        @manager = new ComponentManager
            ..register this
        @pads = []
        if data and (init=data.init)
            # initialize by provided item (data)
            @resuming = yes     # flag for sub-classers
            if init.parent      # must be an aeCAD obect
                @parent = that
                    ..add this  # Register to parent

            @g = init.item

            for @g.children
                #console.log "has child"
                if ..data?.aecad?.part
                    # register as a regular drawing part
                    @[that] = ..
                else
                    # try to convert to aeCAD object
                    unless get-aecad .., this
                        # if failed, try to load by provided loader
                        @_loader ..
        else
            # create from scratch
            {Group} = new PaperDraw
            if data?parent
                @parent = data?.parent
                delete data.parent      # Prevent circular reference errors

            @g = new Group do
                applyMatrix: no         # Insert further items relatively positioned
                parent: @parent?g

            # Set type to implementor class' name
            @set-data 'type', @@@name

            # Merge data with existing one
            if data
                @merge-data '.', that

            # Auto register to parent if provided
            @parent?.add this

            # Save creator class' version information
            if version = @@@["rev_#{@@@name}"]
                console.log "Creating a new #{@@@name}, registering version: #{version}"
                @set-data 'version', version


        @_next_id = 1 # will be used for enumerating pads

    _loader: (item) ->
        console.warn "How do we load the item in #{@@@name}: ", item

    set-data: (keypath, value) ->
        _keypath = prefix-keypath 'aecad', keypath
        set-keypath @g.data, _keypath, value

    get-data: (keypath) ->
        _keypath = prefix-keypath 'aecad', keypath
        get-keypath @g.data, _keypath

    toggle-data: (keypath) ->
        @set-data keypath, not @get-data keypath

    add-data: (keypath, value) ->
        curr = (@get-data keypath) or 0 |> parse-int
        @set-data keypath, curr + value

    merge-data: (keypath, value) ->
        curr = @get-data(keypath) or {}
        curr `merge` value
        @set-data keypath, curr

    send-to-layer: (layer-name) ->
        @g `@scope.send-to-layer` layer-name

    print-mode: (layers, our-side) ->
        # layers: [Array] String array indicates which layers (sides)
        #         to be printed
        # our-side: The side which the first container object is
        #
        # see Container.print-mode for exact code
        #
        console.warn "Print mode requested but no custom method is provided."

    _loader: (item) ->
        # custom loader method for non-standard items
        console.warn "#{@@@name} has a stray item: How do we rehydrate this?:", item

    get: (query) ->
        console.error "NOT IMPLEMENTED: Requested a query: ", query

    position: ~
        -> @g.position
        (val) -> @g.position = val

    bounds: ~
        -> @g.bounds
        (val) -> @g.bounds = val

    selected: ~
        -> @g.selected
        (val) -> @g.selected = val

    g-pos: ~
        # Global position
        ->
            # TODO: I really don't know why ".parent" part is needed. Find out why.
            @g.parent.localToGlobal @g.bounds.center

    name: ~
        -> @get-data \name

    owner: ~
        ->
            _owner = this
            for to 100
                if _owner.parent
                    _owner = _owner.parent
                else
                    break
            return _owner

    nextid: ->
        @_next_id++

    pedigree: ~
        ->
            res = []
            l = @__proto__
            for to 100
                l = l.__proto__
                if l@@name is \Object
                    break
                res.push l
            {names: res.map (.@@name)}

    trigger: !->
        # trigger an event for children
        for @pads
            ..on ...arguments

    on: !->
        # propagate the event to the children by default
        for @pads
            ..on ...arguments

    add-part: (part-name, item) ->
        set-keypath item.data, "aecad.part", part-name
