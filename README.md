# simple-gcp-lakehouse
[architecture image](data/simple-gcp-lakehouse.png)
## Quickstart:

1. Clone the repo
2. Change directory to simple-gcp-lakehouse/terraform
3. run `terraform init`
4. run `terraform apply --auto-approve`
5. Upon successfull application the whole infrastructure will be created
6. Add some data:
Because SQL instance doesn't have the public ip you can connect to it via the reverse-proxy machine. Just ssh to reverse proxy. Install msql-client and create a table
You can import data in the cloud SQL UI

