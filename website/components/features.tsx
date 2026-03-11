import { Wind, Cpu, Layers, Printer } from 'lucide-react';

const features = [
  {
    icon: Wind,
    title: 'Fan Cooling',
    description: 'Direct airflow with Noctua fan mounting',
  },
  {
    icon: Layers,
    title: 'Hexagonal Design',
    description: 'Compact hex shell with voronoi ventilation',
  },
  {
    icon: Cpu,
    title: 'SBC Mounting',
    description: 'Integrated board mounting with connector cutouts',
  },
  {
    icon: Printer,
    title: '3D Printable',
    description: 'Sectioned body with minimal supports',
  },
];

export function Features() {
  return (
    <section className="py-16">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
        {features.map((feature) => (
          <div
            key={feature.title}
            className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-6 text-center hover:border-amber-500/50 transition-colors"
          >
            <feature.icon className="w-10 h-10 text-amber-500 mx-auto mb-4" />
            <h3 className="font-semibold text-white mb-2">{feature.title}</h3>
            <p className="text-sm text-zinc-400">{feature.description}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
