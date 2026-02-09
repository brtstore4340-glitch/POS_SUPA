# Supabase Deployment Guide

This document outlines the process for deploying the Supabase project.

## Prerequisites

1.  **Supabase CLI:** Ensure you have the Supabase CLI installed. If not, install it using `npm i -g supabase`.
2.  **Authentication:** You must be logged into your Supabase account. Run `npx supabase login` and follow the prompts.
3.  **Project Linking:** The local project must be linked to the Supabase project. This is handled by the deployment script.

## Deployment Steps

The deployment process is automated through a PowerShell script.

1.  **Run the script:**
    ```powershell
    ./deploy-supabase.ps1
    ```
2.  **Monitor the output:** The script will handle project linking and deployment. Check the output for any errors.
