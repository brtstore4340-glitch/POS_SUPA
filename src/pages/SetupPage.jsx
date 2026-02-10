import React from 'react';
import { Container } from "@/components/ui/grid";

export default function SetupPage() {
  return (
    <Container className="py-12">
      <div className="max-w-md mx-auto bg-white dark:bg-slate-900 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 p-8">
        <h1 className="text-2xl font-bold text-slate-800 dark:text-slate-200 mb-2">
          Setup Page
        </h1>
        <p className="text-slate-600 dark:text-slate-400">
          This page is a placeholder.
        </p>
      </div>
    </Container>
  );
}

