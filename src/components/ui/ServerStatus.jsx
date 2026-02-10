import React, { useState, useEffect } from "react";
import { systemService } from "@/services/systemService";
import { Wifi, WifiOff, Loader2 } from "lucide-react";

export function ServerStatus() {
  const [status, setStatus] = useState("connecting"); // 'connecting' | 'connected' | 'disconnected'

  useEffect(() => {
    let mounted = true;
    let intervalId = null;

    const checkServer = async () => {
      if (!mounted) return;
      
      const result = await systemService.checkConnection();
      
      if (mounted) {
        setStatus(result.status);
      }
    };

    // Initial check
    checkServer();

    // Set up polling every 30 seconds
    intervalId = setInterval(checkServer, 30000);

    return () => {
      mounted = false;
      if (intervalId) clearInterval(intervalId);
    };
  }, []);

  const getStatusConfig = () => {
    switch (status) {
      case "connected":
        return {
          icon: <Wifi className="w-4 h-4" />,
          color: "text-green-500",
          bgColor: "bg-green-500/10",
          label: "Connected",
        };
      case "disconnected":
        return {
          icon: <WifiOff className="w-4 h-4" />,
          color: "text-red-500",
          bgColor: "bg-red-500/10",
          label: "Disconnected",
        };
      default:
        return {
          icon: <Loader2 className="w-4 h-4 animate-spin" />,
          color: "text-yellow-500",
          bgColor: "bg-yellow-500/10",
          label: "Connecting...",
        };
    }
  };

  const config = getStatusConfig();

  return (
    <div
      className={`
        inline-flex items-center gap-1.5 px-2 py-1 rounded-full
        ${config.bgColor} ${config.color}
        transition-all duration-300
      `}
      title={`Server Status: ${config.label}`}
    >
      {config.icon}
      <span className="text-xs font-medium hidden sm:inline">
        {config.label}
      </span>
    </div>
  );
}

export default ServerStatus;
