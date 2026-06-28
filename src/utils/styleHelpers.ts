export function getImpactClass(evidencia: string): string {
  switch (evidencia) {
    case "Comprobado":
      return "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20";
    case "Situacional":
      return "bg-blue-500/10 text-blue-400 border border-blue-500/20";
    case "Cosmético":
      return "bg-purple-500/10 text-purple-400 border border-purple-500/20";
    default:
      return "bg-gray-500/10 text-gray-400 border border-gray-500/20";
  }
}
