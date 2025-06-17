import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import { format, toZonedTime } from "date-fns-tz"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// IST timezone utilities
const IST_TIMEZONE = 'Asia/Kolkata';

export function formatDateIST(date: string | Date, formatString = 'MMM dd, yyyy HH:mm'): string {
  const dateObj = typeof date === 'string' ? new Date(date) : date;
  const zonedDate = toZonedTime(dateObj, IST_TIMEZONE);
  return format(zonedDate, formatString, { timeZone: IST_TIMEZONE });
}

export function formatTimeIST(date: string | Date): string {
  return formatDateIST(date, 'HH:mm');
}

export function formatDateOnlyIST(date: string | Date): string {
  return formatDateIST(date, 'MMM dd, yyyy');
}

export function formatDateTimeIST(date: string | Date): string {
  return formatDateIST(date, 'MMM dd, yyyy HH:mm:ss');
}
