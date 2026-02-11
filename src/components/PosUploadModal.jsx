import React from "react";
import { X } from "lucide-react";
import { cn } from "../utils/cn";

export default function PosUploadModal({ open, onClose, isDarkMode = false }) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className={cn(
        "w-full max-w-md rounded-3xl shadow-2xl border overflow-hidden p-6",
        isDarkMode ? "bg-slate-950 border-slate-800 text-white" : "bg-white border-slate-200 text-slate-900"
      )}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold">Product Upload</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition">
            <X size={20} />
          </button>
        </div>
        
        <p className="text-slate-500 dark:text-slate-400">
          Upload functionality is currently disabled for security updates. Please contact the administrator.
        </p>
        
        <div className="mt-6 flex justify-end">
          <button onClick={onClose} className="px-4 py-2 bg-blue-600 text-white rounded-xl font-bold hover:bg-blue-700 transition">
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

