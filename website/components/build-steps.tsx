import type { Axes, Fastener } from '../types/manifest';

interface BuildStepsProps {
  hardware: Fastener[];
  boards: Axes['board'];
}

/** What happens after the download, in the order it happens -- hence the numbers. */
export function BuildSteps({ hardware, boards }: BuildStepsProps) {
  // Antenna posts only apply to some cells; the build sheet counts those for the real rack.
  const perUnit = hardware
    .filter((h) => h.perUnit > 0 || h.perBoard)
    .map((h) => ({
      id: h.id,
      // The manifest names carry their purpose after a dash; the list only needs the part.
      name: h.name.split(' — ')[0],
      qty: h.perUnit,
      // "4 on Rock 5B+, 7 on RPi 5 · Pironman" -- the count genuinely differs by board.
      byBoard: h.perBoard
        ? boards.values
            .map((b) => `${h.perUnit + (h.perBoard?.[b] ?? 0)} on ${boards.labels[b] ?? b}`)
            .join(', ')
        : null,
    }));

  const steps = [
    {
      title: 'Print',
      body: (
        <p>
          PETG is the tested material. The zip holds every STL your rack needs and a build sheet
          listing quantities, so nothing has to be worked out at the printer.
        </p>
      ),
    },
    {
      title: 'Fit the hardware',
      body: (
        <>
          <p>Each cell takes:</p>
          <ul className="mt-2 space-y-1">
            {perUnit.map((h) => (
              <li key={h.id} className="tabular-nums">
                {h.byBoard ? (
                  <>
                    {h.name}: <span className="text-zinc-200">{h.byBoard}</span>
                  </>
                ) : (
                  <>
                    <span className="text-zinc-200">{h.qty}×</span> {h.name}
                  </>
                )}
              </li>
            ))}
          </ul>
        </>
      ),
    },
    {
      title: 'Slide it together',
      body: (
        <p>
          Cells join on their printed dovetails, pushed in from the back. A raised cell's foot
          slides in the same way. The build sheet totals the hardware for the whole rack.
        </p>
      ),
    },
  ];

  return (
    <section aria-labelledby="steps-heading" className="py-20 md:py-28">
      <h2
        id="steps-heading"
        className="text-3xl font-bold tracking-tight text-zinc-50 [font-stretch:112.5%] md:text-4xl"
      >
        From download to shelf
      </h2>
      <ol className="mt-12 grid gap-10 md:grid-cols-3 md:gap-8">
        {steps.map((s, i) => (
          <li key={s.title} className="border-t border-zinc-800 pt-6">
            <span
              aria-hidden
              className="block text-5xl font-bold leading-none text-zinc-700 [font-stretch:125%]"
            >
              {i + 1}
            </span>
            <h3 className="mt-5 text-lg font-semibold text-zinc-100">{s.title}</h3>
            <div className="mt-2 max-w-[36ch] text-sm leading-relaxed text-zinc-400">{s.body}</div>
          </li>
        ))}
      </ol>
    </section>
  );
}
