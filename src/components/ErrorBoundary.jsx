import { Component } from 'react';

export class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary caught:', error, errorInfo);
    this.setState({ errorInfo });
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center p-4 bg-red-50">
          <div className="max-w-2xl w-full bg-white border border-red-200 rounded-lg p-6 shadow-lg">
            <h2 className="text-xl font-bold text-red-800 mb-4">Application Error</h2>
            <div className="mb-4">
              <p className="text-sm font-semibold text-red-600">Error:</p>
              <pre className="text-xs text-red-700 bg-red-100 p-2 rounded overflow-auto">
                {this.state.error?.toString() || 'Unknown error'}
              </pre>
            </div>
            {this.state.errorInfo && (
              <div className="mb-4">
                <p className="text-sm font-semibold text-red-600">Component Stack:</p>
                <pre className="text-xs text-red-700 bg-red-100 p-2 rounded overflow-auto">
                  {this.state.errorInfo.componentStack}
                </pre>
              </div>
            )}
            <button
              onClick={() => {
                this.setState({ hasError: false, error: null, errorInfo: null });
                window.location.reload();
              }}
              className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
            >
              Reload Page
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

export default ErrorBoundary;
