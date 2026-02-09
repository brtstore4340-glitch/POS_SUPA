import React from 'react';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { 
      hasError: false, 
      error: null, 
      errorInfo: null,
      errorCount: 0
    };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    console.error('🔴 ErrorBoundary caught error:', {
      error: error,
      message: error?.message,
      stack: error?.stack,
      componentStack: errorInfo?.componentStack,
      timestamp: new Date().toISOString()
    });
    
    this.setState(prevState => ({
      error: error,
      errorInfo: errorInfo,
      errorCount: prevState.errorCount + 1
    }));

    // ถ้า error มากเกิน 3 ครั้ง ให้ reload หน้า
    if (this.state.errorCount >= 2) {
      console.warn('⚠️ Too many errors, reloading page...');
      setTimeout(() => {
        window.location.reload();
      }, 2000);
    }
  }

  handleReset = () => {
    this.setState({ 
      hasError: false, 
      error: null, 
      errorInfo: null 
    });
  };

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          padding: '40px',
          maxWidth: '800px',
          margin: '0 auto',
          fontFamily: 'system-ui, -apple-system, sans-serif'
        }}>
          <h1 style={{ color: '#dc2626' }}>⚠️ เกิดข้อผิดพลาด</h1>
          <p style={{ fontSize: '16px', color: '#6b7280', marginBottom: '20px' }}>
            แอปพลิเคชันเกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่อีกครั้ง
          </p>
          
          <div style={{ marginBottom: '20px' }}>
            <button 
              onClick={this.handleReset}
              style={{
                padding: '12px 24px',
                backgroundColor: '#3b82f6',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                fontSize: '16px',
                cursor: 'pointer',
                marginRight: '10px'
              }}
            >
              ลองอีกครั้ง
            </button>
            <button 
              onClick={() => window.location.reload()}
              style={{
                padding: '12px 24px',
                backgroundColor: '#6b7280',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                fontSize: '16px',
                cursor: 'pointer'
              }}
            >
              รีเฟรชหน้า
            </button>
          </div>

          <details style={{ 
            backgroundColor: '#f3f4f6', 
            padding: '16px', 
            borderRadius: '8px',
            cursor: 'pointer'
          }}>
            <summary style={{ fontWeight: 'bold', marginBottom: '10px' }}>
              รายละเอียดข้อผิดพลาด (สำหรับนักพัฒนา)
            </summary>
            <pre style={{ 
              whiteSpace: 'pre-wrap', 
              fontSize: '12px',
              overflow: 'auto',
              maxHeight: '400px'
            }}>
              <strong>Error:</strong> {this.state.error?.toString()}
              {'\n\n'}
              <strong>Stack:</strong> {this.state.error?.stack}
              {'\n\n'}
              <strong>Component Stack:</strong> {this.state.errorInfo?.componentStack}
            </pre>
          </details>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;