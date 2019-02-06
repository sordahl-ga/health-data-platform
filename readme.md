# Health Data Ingest Platform

A versatile sample ingest platform for health data. Including HL7, FHIR, Unstructured Documents, Images, PDF Data, etc... into a 
CosmosDB database and data lake storage account.  There is an NLP pipeline that will extract and code medical concepts discovered in unstructured documents and images. An 
Azure Search Index with extracted text content and medical concept facets is also created and dynamically updated on message/file ingest.

## Public Demo Instructions
Note: The public demo is subject to frequent updates and periodic unavailability for maintenance/improvements.

Coming Soon!!!


## Deploying your own Health Data Ingest Platform

1. [Get or Obtain a valid Azure Subscription](https://azure.microsoft.com/en-us/free/)
2. [Install Azure CLI 2.0 on Linux based System](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)
3. [Download/Clone this repo](https://www.github.com)
4. [Obtain UMLS Terminology Service Access from the NIH](https://uts.nlm.nih.gov//license.html) (In order to support medical coding in the NLP Pipeline)
5. Open a shell or command window into the Azure CLI 2.0 environment
6. Set the following enviornment variables:

   ```
	HDPUMLSUSER=<your umls user name>
	HDPUMLSPASSWORD=<your umls user password>
	```
7. Run the deployhdpingest.bash script in this repo and follow the prompts
8. Obtain Access keys and Connect the HDP Internal VNET to the Platform Transform Function App:
    + [Access Azure Portal](https://portal.azure.com)
    + Goto the Resource Group created/selected under the subscription you installed too
    + Click on the [HDPTransformXXXX function app](https://github.com/sordahl-ga/TransformFunctions/tree/hdporigin) that was created with your install
    + From the Overview Tab copy the URL to the Function App and save it for future reference
    + From the Configured Features Section of the Overview Tab click on Function App Settings and click the copy action next to the _master key in host keys. Securely save this key for future reference.
    + Click on the Platform Features Tab
    + Click on Networking under Networking
    + Click on configure VNET Integration
    + Click on Add Vnet (Preview) Icon
    + On the Virtual Network Drop Down select the VNET created which should be your resource group name followed by vnet
    + Click the create new subnet radio button under subnet
    + Add a subnet named functionappaccess
    + Add an available subnet CIDR block of /24 size
    + Save your changes

9. Test the ingest pipeline for unstructured documents
    + Locate the sample document medtest.png in the root directory of the repo
    + Use an image viewer to see contents
    + From the linux command shell run the following command to test the NLP Document Extract Pipeline
      ```
        curl -H "Content-Type:application/octet-stream" --data-binary @medtext.png https://hdptransformXXXX.azurewebsites.net/api/NLPExtractEntitiesFile?code=<your function key from above>&updatesearch=true
      ``` 
    + Congratulations!!! The text in the image file was extracted and Medical NLP run against it and search index updated with results.

10. You can also send in HL7 messages using the local HL7 MLLP Relay or deploy the HL7 MLLP Relay using the VNET in the HDP you just deployed.  (runhl7relay or deployhl7relay) Documentation Coming Soon!!!    
11. You can also post FHIR Messages using the FHIR Server deployed Documentation Coming Soon!!!    
## Authors

* **Steven Ordahl** - Microsoft HLS Apps and Infrastructure Cloud Architect
