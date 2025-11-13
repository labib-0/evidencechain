#!/bin/bash

# EvidenceChain - Complete Setup Script for Local Development
# This script automates the entire setup process

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}EvidenceChain Local Setup${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js is not installed. Please install Node.js v16+${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm is not installed. Please install npm${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}\n"

# Step 1: Install Supabase CLI
echo -e "${BLUE}Step 1: Installing Supabase CLI...${NC}"
npm install -g supabase
echo -e "${GREEN}✓ Supabase CLI installed${NC}\n"

# Step 2: Initialize Supabase project
echo -e "${BLUE}Step 2: Initializing Supabase project...${NC}"
if [ ! -d "supabase" ]; then
    supabase init
fi
echo -e "${GREEN}✓ Supabase initialized${NC}\n"

# Step 3: Start Supabase
echo -e "${BLUE}Step 3: Starting Supabase (this may take 1-2 minutes)...${NC}"
supabase start
echo -e "${GREEN}✓ Supabase started${NC}\n"

# Step 4: Run database migrations
echo -e "${BLUE}Step 4: Running database migrations...${NC}"
supabase db push
echo -e "${GREEN}✓ Database migrations completed${NC}\n"

# Step 5: Create React app
echo -e "${BLUE}Step 5: Creating React frontend...${NC}"
if [ ! -d "evidencechain-frontend" ]; then
    mkdir -p evidencechain-frontend/src/{pages,components,services,hooks,utils}
    mkdir -p evidencechain-frontend/public
fi
echo -e "${GREEN}✓ Frontend directory created${NC}\n"

# Step 6: Setup frontend
echo -e "${BLUE}Step 6: Setting up frontend dependencies...${NC}"
cd evidencechain-frontend
npm install
echo -e "${GREEN}✓ Dependencies installed${NC}\n"

# Step 7: Create .env file
echo -e "${BLUE}Step 7: Creating environment variables...${NC}"
echo "REACT_APP_SUPABASE_URL=http://localhost:54321" > .env
echo "REACT_APP_SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJhdWQiOiJhdXRoZWQtdXNlcnMiLCJpYXQiOjE2MjMzNjkwMjIsImV4cCI6MTYyNDU3OTAyMn0.rQL80O_pIGSCIQx89OMfOrjP41I9ETyT1ISZpsFH50w" >> .env
echo "REACT_APP_JWT_EXPIRY=24h" >> .env
echo -e "${GREEN}✓ Environment variables created${NC}\n"

# Step 8: Create storage buckets
echo -e "${BLUE}Step 8: Creating storage buckets...${NC}"
echo "Please create 'evidence' and 'reports' buckets in Supabase Studio"
echo "1. Open http://localhost:54323"
echo "2. Go to Storage → Buckets"
echo "3. Create 'evidence' bucket (private)"
echo "4. Create 'reports' bucket (private)"
echo -e "${GREEN}✓ Storage setup instructions shown${NC}\n"

# Step 9: Summary
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}=====================================${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo "1. Supabase Studio: http://localhost:54323"
echo "2. Frontend Dev Server: npm start (from evidencechain-frontend directory)"
echo "3. Frontend App: http://localhost:3000"
echo ""
echo -e "${BLUE}Quick Start:${NC}"
echo "cd evidencechain-frontend"
echo "npm start"
echo ""
echo -e "${BLUE}Default Test Credentials:${NC}"
echo "Email: test@example.com"
echo "Password: TestPassword123"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
