#!/bin/bash
BUCKET=aws-andy-test-001
aws s3 cp --recursive ./jars s3://${BUCKET}/
