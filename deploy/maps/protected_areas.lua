local tables = {}

tables.protected_areas = osm2pgsql.define_area_table('protected_areas', {
    { column = 'name', type = 'text' },
    { column = 'boundary', type = 'text' },
    { column = 'leisure', type = 'text' },
    { column = 'protect_class', type = 'text' },
    { column = 'protection_title', type = 'text' },
    { column = 'operator', type = 'text' },
    { column = 'designation', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multipolygon', projection = 4326, not_null = true },
})

local function is_protected(tags)
    return tags.boundary == 'protected_area'
        or tags.boundary == 'national_park'
        or tags.leisure == 'nature_reserve'
        or tags.protect_class ~= nil
end

local function add_area(object, geom)
    if geom:is_null() then
        return
    end

    tables.protected_areas:insert({
        name = object.tags.name,
        boundary = object.tags.boundary,
        leisure = object.tags.leisure,
        protect_class = object.tags.protect_class,
        protection_title = object.tags.protection_title,
        operator = object.tags.operator,
        designation = object.tags.designation,
        tags = object.tags,
        geom = geom,
    })
end

function osm2pgsql.process_way(object)
    if object.is_closed and is_protected(object.tags) then
        add_area(object, object:as_polygon())
    end
end

function osm2pgsql.process_relation(object)
    local relation_type = object.tags.type
    if (relation_type == 'multipolygon' or relation_type == 'boundary') and is_protected(object.tags) then
        add_area(object, object:as_multipolygon())
    end
end
