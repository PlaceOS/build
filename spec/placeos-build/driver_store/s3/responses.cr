LIST_XML = <<-XML
           <?xml version="1.0" encoding="UTF-8"?>
           <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Name>placeos-drivers</Name><Prefix></Prefix><Marker></Marker><MaxKeys>1000</MaxKeys><IsTruncated>false</IsTruncated><Contents><Key>dummy.html</Key><LastModified>2021-07-02T12:23:04.000Z</LastModified><ETag>&quot;d41d8cd98f00b204e9800998ecf8427e&quot;</ETag><Size>0</Size><StorageClass>STANDARD</StorageClass></Contents><Contents><Key>test-copy.html</Key><LastModified>2021-07-02T10:58:20.000Z</LastModified><ETag>&quot;d41d8cd98f00b204e9800998ecf8427e&quot;</ETag><Size>0</Size><StorageClass>STANDARD</StorageClass></Contents><Contents><Key>test.html</Key><LastModified>2021-06-11T03:49:31.000Z</LastModified><ETag>&quot;d41d8cd98f00b204e9800998ecf8427e&quot;</ETag><Size>0</Size><StorageClass>STANDARD</StorageClass></Contents></ListBucketResult>
           XML

COPY_XML = <<-XML
           <?xml version="1.0" encoding="UTF-8"?>
           <CopyObjectResult>
               <LastModified>2009-10-28T22:32:00</LastModified>
               <ETag>&quot;etag&quot;</ETag>
           <CopyObjectResult>
           XML
