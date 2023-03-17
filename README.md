# Generate a REST API from SQL 

Install the DAB CLI

https://learn.microsoft.com/en-us/azure/data-api-builder/get-started/get-started-with-data-api-builder

## Create a SQL instance 

Create a SQL database with an empty database.

```
$sid="<your subcription identifier here>"
$rg="<resource group name>"
$administratorPassword="__Holasql4320"

az login
az account set --subscription $sid

# create sql instance and empty database
$result = az deployment group create --resource-group $rg --template-file ./infra/sqldb.bicep --parameters administratorLoginPassword=$administratorPassword | ConvertFrom-Json

# read output values
$sqlServerName = $result.properties.outputs.sqlname.value
$databaseName = $result.properties.outputs.dbname.value
$administratorLogin = $result.properties.outputs.administratorLogin.value

```

## Seed the DB

Seed the database with the WideWorldImporters SQL sample.

```
$bacpac="https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Standard.bacpac"

$localpath="/bacpac/WideWorldImporters-Standard.bacpac"

$sto="holadabcli"

# create storage account
az storage account create --name $sto --resource-group $rg --location westeurope --sku Standard_LRS

# create container
az storage container create --name sql --account-name $sto

# get connection string
$cn = az storage account show-connection-string --name $sto --resource-group $rg --query "connectionString" -o tsv

# upload bacpac to storage account
az storage blob upload --account-name $sto --connection-string $cn --container-name sql --type block --file $localpath

# get storage access key
$key = az storage account keys list --account-name $sto --resource-group $rg --query [0].value -o tsv

# restore bacpac (can take up to 30 mins)
az sql db import -s $sqlServerName -n $databaseName -g $rg -u $administratorLogin -p $administratorPassword --storage-key-type StorageAccessKey --storage-key $key --storage-uri "https://$sto.blob.core.windows.net/sql/WideWorldImporters-Standard.bacpac"

```

## DAB

Get the connecton string to the SQL database and initialize the DAB tool.

https://learn.microsoft.com/en-us/azure/data-api-builder/get-started/get-started-azure-sql

```
$sqlCN = az sql db show-connection-string --server $sqlServerName --name $databaseName --client ado.net -o tsv
$sqlCN = $sqlCN.replace('<username>',$administratorLogin).replace('<password>',$administratorPassword)

# initialize the DAB config file
dab init --database-type "mssql" --connection-string $sqlcn --host-mode "Development"

# add the Customers entity (view)
dab add Customers --source Website.Customers --permissions "anonymous:read"  --source.type "view" 

dab start
```

you can now check the API hosted on localhost:5000

![](imgs/customers-rest.jpg)
