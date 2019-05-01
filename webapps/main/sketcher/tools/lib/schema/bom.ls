# global imports
require! 'prelude-ls': {
    find, empty, unique, difference, max, keys, flatten, filter, values
}

# deps
require! './deps': {find-comp, PaperDraw, text2arr, get-class, get-aecad}
require! './lib': {parse-name}


replace-vars = (src-data, target-obj) -> 
    res = {}
    for k, v of target-obj
        for var-name, var-value of src-data
            regex = new RegExp("{{#{var-name}}}")
            k = k.replace regex, var-value

        if typeof! v is \Object 
            v = replace-vars src-data, v
        res[k] = v 
    return res 

export do
    get-bom: ->
        bom = {}
        if typeof! @data.bom is \Array
            throw new Error "BOM should be Object, not Array"

        @data.bom = replace-vars @params, @data.bom
        for type, val of @data.bom 
            if typeof! val is 'String'
                # this is shorthand for "empty parametered instances"
                val = {'': val}

            # params: list of instances
            instances = []
            for params, names of val
                # replace dynamic component type here 
                instances.push do
                    params: params
                    names: text2arr names

            # create
            for group in instances
                for name in group.names
                    # create every #name with params: group.params
                    if name of bom
                        throw new Error "Duplicate instance: #{name}"
                    #console.log "Creating bom item: ", name, "as an instance of ", type, "group:", group
                    bom[name] =
                        name: name
                        params: group.params
                        parent: @name
                        data: @data.schemas?[type]
                        type: type
                        schema-name: "#{@name}-#{name}" # for convenience in constructor
                        prefix: [@prefix.replace(/\.$/, ''), name, ""].join '.' .replace /^\./, ''

        @find-unused bom
        #console.log "Compiled bom is: ", JSON.stringify bom
        @bom = bom

    get-bom-components: ->
        b = flatten [..name for filter (-> not it.data), values @get-bom!]
        #console.log "bom raw components found:", b
        return b

    get-bom-list: -> 
        # group by type, and then value 
        comp = [{..type, ..value, ..name} for values @components]
        arr = comp 
        g1 = {}
        for i in arr
            type1 = i["type"]
            unless g1[type1]
                g1[type1] = [] 
            g1[type1].push i
            
        g2 = {}
        for type1, arr of g1 
            g2[type1] = {}
            for i in arr 
                type2 = i["value"]
                unless g2[type1][type2]
                    g2[type1][type2] = [] 
                g2[type1][type2].push i 

        flatten-bom = []
        for type, v of g2
            for value, c of v 
                flatten-bom.push {
                    count: c.length, 
                    type, 
                    value, 
                    instances: [..name for c]
                }

        return flatten-bom



    find-unused: (bom) ->
        # detect unused pads of footprints in BOM:
        required-pads = {}
        for instance, args of bom
            #console.log "Found #{args.type} instance: #{instance}"
            if instance.starts-with '_'
                continue
            pads = if args.data
                # this is a sub-circuit, use its `iface` as `pad`s
                that.iface |> text2arr
            else
                # outsourced component, use its iface (pads)
                Component = get-class args.type
                sample = new Component (args.params or {})
                iface = values sample.iface
                sample.remove!
                iface

            for pad in pads or []
                required-pads["#{instance}.#{pad}"] = null

        # iface pins are required to be used
        for @iface
            required-pads["#{..}"] = "iface"

        # find used iface pins
        for id, net of @data.netlist
            for (text2arr net) ++ [id]
                #console.log "...pad #{..} is used."
                if .. of required-pads
                    delete required-pads[..]

        for @no-connect
            if .. of required-pads
                delete required-pads[..]

        # throw the exception if there are unused pads
        unused = keys required-pads
        unless empty unused
            msg = if required-pads[unused.0] is \iface
                "Unconnected iface:"
            else
                "Unused pads:"
            throw new Error "#{msg} #{unused.map (~> "#{@prefix}#{it}") .join ','}"
