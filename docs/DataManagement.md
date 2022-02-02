# New Data Management system

## How does it work ?

The data management system was replace by this new schema:

    - The datastore object are now like a "Table"
        - one name
        - one environnement id (application environnement ex: Prod/Test/...)
        - many data

    - We have one object Data, simply one id and one data (JSON)
    - We have one object DataReferences, this object link two Data
        - RefsBy the Data referenced
        - Refs the Data that reference the RefBy Data

    - Probably one UserData table two give user data to application

    In practice :

        The datastore are now like "Table" that we can "store" Data object in it.
        We can make links betwen two Data (with DataReferences), the link are directional one data reference an other example:

        data1: {                        
            Table: users                
            data: {name: test}          
        }                               

        data2: {                        
            Table: score                
            data: {point: 10}           
            refBy: [data1]              
        }

        In this example we create one data in table user "{name: test}" and one data in the table score "{point: 10}",
        data1 reference data2 and data2 was referenced by data1, so we have this two object:

        data1{
            Table: users
            data: {name: test}
            refs: [data2]
            refBy:[]
        }

        data2: {
            Table: score
            data: {point: 10}
            refs: []
            refBy: [data1]
        }


## What has changed  ?

ApplicationRunner:

    - The datastore object was move from server to ApplicationRunner/db_schema
    - New data Object (Data/DataReference/ and the future next one) was places in ApplicationRunner/db_schema
    - Query module was create and have all function that we need for insert/update/dalete
        (basic get function was made but stile doesn't work properly)
    - An Repo was created for ApplicationRunner to handle test
    - We also have added Exqlite3 (ram database) and FakeLenraEnrionment (clone of Lenra.Environment)
      For testing data system
    - new config line was added:
        ApplicationRunner:
            lenra_environment_schema: Give the Environement schema (FakeLenraEnvironment in ApplicationRunner and Environement in Lenra)
            repo: Give the Repo to ApplicationRunner

    work needed:
        - define get json format:
        https://backand-docs.readthedocs.io/en/latest/apidocs/nosql_query_language/index.html
        - create get function
        - parse ui return by openfass to get data and call listener

Server:

    - New APi route for Insert/Update/Delete
    - New Controller for the new route
    - New migration to modify Datastore and create Data/DataReference

    work needed:
    - change datastore_service to fit the new datastore system
    - modify application_runner_adapter to fit new system 