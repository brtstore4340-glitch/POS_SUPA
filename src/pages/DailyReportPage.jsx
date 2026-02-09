// src/pages/DailyReportPage.jsx
import React, { useState, useCallback } from 'react';
import { reportService } from '../services/reportService';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/card';
import ProtectedRoute from '../modules/auth/ProtectedRoute';

function DailyReportContent() {
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchReport = useCallback(async () => {
    setError(null);
    setLoading(true);
    try {
      const data = await reportService.getDailySalesSummary(date);
      setSummary(data);
    } catch (err) {
      setError(err.message);
      setSummary(null);
    } finally {
      setLoading(false);
    }
  }, [date]);

  return (
    <div className="p-4 sm:p-6 md:p-8">
      <Card className="w-full max-w-2xl mx-auto">
        <CardHeader>
          <CardTitle>Daily Sales Report</CardTitle>
          <CardDescription>Select a date to view the sales summary.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex gap-2 mb-4">
            <Input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="max-w-xs"
            />
            <Button onClick={fetchReport} disabled={loading}>
              {loading ? 'Generating...' : 'Generate Report'}
            </Button>
          </div>

          {error && <p className="text-red-500">{error}</p>}

          {summary && (
            <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Card>
                <CardHeader>
                  <CardTitle>Total Sales</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-bold">
                    ฿{summary.total_sales.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>Transactions</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-bold">{summary.transaction_count}</p>
                </CardContent>
              </Card>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export default function DailyReportPage() {
    return (
        <ProtectedRoute allowRoles={['admin']}>
            <DailyReportContent />
        </ProtectedRoute>
    )
}
