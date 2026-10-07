# LocalBuka DevOps Case Study — Solution Report

**Candidate:** Acecode2021
**Track:** DevOps
**Live API:** http://13.60.14.0/health
**Personal repo:** https://github.com/Acecode2021/localbuka-devepos

## Note on repository structure

The starter files in this repo are for a full-stack (React / NestJS / React Native) assessment. The case study attached to my HR email is the DevOps Case Study, a different track. My DevOps submission is in the `devops-submission/` folder.

## 1. Local Setup Instructions

```bash
cd devops-submission
npm install
npm test
npm start
# API runs at http://localhost:3000

docker build -t localbuka-api:local .
docker run --rm -p 3000:3000 localbuka-api:local
