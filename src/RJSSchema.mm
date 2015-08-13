//
//  RJSSchema.m
//  RealmJS
//
//  Created by Ari Lazier on 5/5/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

#import "RJSSchema.hpp"
#import "object_store.hpp"

namespace realm {
    struct SchemaWrapper {
        Schema *schema;
        bool owned;
        ~SchemaWrapper() {
            if (owned) {
                delete schema;
            }
        }
    };
}

using namespace realm;

JSClassRef RJSSchemaClass() {
    static JSClassRef s_schemaClass = RJSCreateWrapperClass<SchemaWrapper *>("Schema");
    return s_schemaClass;
}

JSObjectRef RJSSchemaCreate(JSContextRef ctx, Schema &schema) {
    SchemaWrapper *wrapper = new SchemaWrapper();
    wrapper->schema = &schema;
    wrapper->owned = false;
    return RJSWrapObject(ctx, RJSSchemaClass(), wrapper);
}

static std::map<std::string, JSValueRef> s_prototypes;
JSValueRef RJSPrototypeForClassName(const std::string &className) {
    return s_prototypes[className];
}

static inline Property RJSParseProperty(JSContextRef ctx, JSObjectRef propertyObject) {
    static JSStringRef nameString = JSStringCreateWithUTF8CString("name");
    static JSStringRef typeString = JSStringCreateWithUTF8CString("type");
    static JSStringRef objectTypeString = JSStringCreateWithUTF8CString("objectType");

    Property prop;
    prop.name = RJSValidatedStringProperty(ctx, propertyObject, nameString);

    std::string type = RJSValidatedStringProperty(ctx, propertyObject, typeString);
    if (type == "RealmTypeBool") {
        prop.type = PropertyTypeBool;
    }
    else if (type == "RealmTypeInt") {
        prop.type = PropertyTypeInt;
    }
    else if (type == "RealmTypeFloat") {
        prop.type = PropertyTypeFloat;
    }
    else if (type == "RealmTypeDouble") {
        prop.type = PropertyTypeDouble;
    }
    else if (type == "RealmTypeString") {
        prop.type = PropertyTypeString;
    }
    else if (type == "RealmTypeDate") {
        prop.type = PropertyTypeDate;
    }
    else if (type == "RealmTypeData") {
        prop.type = PropertyTypeData;
    }
    else if (type == "RealmTypeObject") {
        prop.type = PropertyTypeObject;
        prop.object_type =  RJSValidatedStringProperty(ctx, propertyObject, objectTypeString);
        prop.is_nullable = true;
    }
    else if (type == "RealmTypeArray") {
        prop.type = PropertyTypeArray;
        prop.object_type =  RJSValidatedStringProperty(ctx, propertyObject, objectTypeString);
    }
    else {
        prop.type = PropertyTypeObject;
        prop.object_type = type;
        prop.is_nullable = true;
    }
    return prop;
}

static inline ObjectSchema RJSParseObjectSchema(JSContextRef ctx, JSObjectRef objectSchemaObject) {
    static JSStringRef schemaString = JSStringCreateWithUTF8CString("schema");
    static JSStringRef prototypeString = JSStringCreateWithUTF8CString("prototype");
    JSObjectRef prototypeObject = NULL;
    JSValueRef prototypeValue = RJSValidatedPropertyValue(ctx, objectSchemaObject, prototypeString);
    if (!JSValueIsUndefined(ctx, prototypeValue)) {
        prototypeObject = RJSValidatedValueToObject(ctx, prototypeValue);
        objectSchemaObject = RJSValidatedObjectProperty(ctx, prototypeObject, schemaString, "Realm object prototype must have a 'schema' property.");
    }
    else {
        JSValueRef subSchemaValue = RJSValidatedPropertyValue(ctx, objectSchemaObject, schemaString);
        if (!JSValueIsUndefined(ctx, subSchemaValue)) {
            objectSchemaObject = RJSValidatedValueToObject(ctx, subSchemaValue);
        }
    }

    static JSStringRef propertiesString = JSStringCreateWithUTF8CString("properties");
    JSObjectRef propertiesObject = RJSValidatedObjectProperty(ctx, objectSchemaObject, propertiesString, "ObjectSchema object must have a 'properties' array.");

    ObjectSchema objectSchema;
    static JSStringRef nameString = JSStringCreateWithUTF8CString("name");
    objectSchema.name = RJSValidatedStringProperty(ctx, objectSchemaObject, nameString);

    size_t numProperties = RJSValidatedArrayLength(ctx, propertiesObject);
    for (unsigned int p = 0; p < numProperties; p++) {
        JSObjectRef property = RJSValidatedObjectAtIndex(ctx, propertiesObject, p);
        objectSchema.properties.emplace_back(RJSParseProperty(ctx, property));
    }

    // store prototype
    if (prototypeObject) {
        JSValueProtect(ctx, prototypeObject);
        s_prototypes[objectSchema.name] = prototypeObject;
    }

    return objectSchema;
}

realm::Schema RJSParseSchema(JSContextRef ctx, JSObjectRef jsonObject) {
    Schema schema;
    size_t length = RJSValidatedArrayLength(ctx, jsonObject);
    for (unsigned int i = 0; i < length; i++) {
        JSObjectRef jsonObjectSchema = RJSValidatedObjectAtIndex(ctx, jsonObject, i);
        ObjectSchema objectSchema = RJSParseObjectSchema(ctx, jsonObjectSchema);
        schema[objectSchema.name] = std::move(objectSchema);
     }

    return schema;
}