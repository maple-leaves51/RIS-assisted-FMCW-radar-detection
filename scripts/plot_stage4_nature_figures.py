"""Create Nature-style Stage 4 two-dimensional and three-dimensional RD figures.

The script reads the MATLAB source data produced by main_stage4_rd_detection.m.
It only handles plotting/export; MATLAB remains responsible for radar simulation.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import cm
from scipy.io import loadmat


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_ROOT / "outputs" / "data" / "stage4_rd_four_targets_latest.mat"
FIGURE_DIR = PROJECT_ROOT / "outputs" / "figures"


def configure_matplotlib() -> None:
    mpl.rcParams.update(
        {
            "font.family": "sans-serif",
            "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans", "sans-serif"],
            "svg.fonttype": "none",
            "pdf.fonttype": 42,
            "font.size": 7,
            "axes.spines.right": False,
            "axes.spines.top": False,
            "axes.linewidth": 0.75,
            "axes.labelsize": 7,
            "axes.titlesize": 8,
            "xtick.labelsize": 6.5,
            "ytick.labelsize": 6.5,
            "legend.frameon": False,
            "figure.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )


def field(obj, name: str) -> np.ndarray:
    return np.asarray(getattr(obj, name)).astype(float).reshape(-1)


def export_figure(fig: mpl.figure.Figure, stem: str) -> None:
    FIGURE_DIR.mkdir(parents=True, exist_ok=True)
    base = FIGURE_DIR / stem
    fig.savefig(base.with_suffix(".svg"), bbox_inches="tight")
    fig.savefig(base.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(base.with_suffix(".png"), dpi=600, bbox_inches="tight")
    fig.savefig(base.with_suffix(".tiff"), dpi=600, bbox_inches="tight")


def load_source() -> dict[str, object]:
    return loadmat(DATA_PATH, squeeze_me=True, struct_as_record=False)


def crop_rd(
    rd_db: np.ndarray,
    range_axis: np.ndarray,
    velocity_axis: np.ndarray,
    range_lim: tuple[float, float],
    velocity_lim: tuple[float, float],
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    range_mask = (range_axis >= range_lim[0]) & (range_axis <= range_lim[1])
    velocity_mask = (velocity_axis >= velocity_lim[0]) & (velocity_axis <= velocity_lim[1])
    return rd_db[np.ix_(range_mask, velocity_mask)], range_axis[range_mask], velocity_axis[velocity_mask]


def add_panel_label(ax: mpl.axes.Axes, label: str) -> None:
    ax.text(
        -0.12,
        1.06,
        label,
        transform=ax.transAxes,
        fontsize=9,
        fontweight="bold",
        va="bottom",
        ha="left",
    )


def draw_heatmap(
    ax: mpl.axes.Axes,
    rd_db: np.ndarray,
    range_axis: np.ndarray,
    velocity_axis: np.ndarray,
    title: str,
    clim: tuple[float, float],
    targets,
    detection,
    show_ylabel: bool,
) -> mpl.image.AxesImage:
    image = ax.imshow(
        rd_db,
        origin="lower",
        aspect="auto",
        extent=[velocity_axis[0], velocity_axis[-1], range_axis[0], range_axis[-1]],
        cmap="viridis",
        vmin=clim[0],
        vmax=clim[1],
        interpolation="nearest",
    )
    ax.scatter(field(targets, "velocity_mps"), field(targets, "range_m"), marker="x", s=28, c="#D62728", linewidths=1.1)
    ax.scatter(
        field(detection, "peakVelocity_mps"),
        field(detection, "peakRange_m"),
        marker="o",
        s=22,
        facecolors="none",
        edgecolors="white",
        linewidths=0.9,
    )
    for idx, (vel, rng) in enumerate(zip(field(targets, "velocity_mps"), field(targets, "range_m")), start=1):
        ax.text(vel + 0.12, rng + 0.45, f"T{idx}", color="white", fontsize=6.4, weight="bold")
    ax.set_title(title, pad=3)
    ax.set_xlabel("Velocity (m s$^{-1}$)")
    if show_ylabel:
        ax.set_ylabel("Range (m)")
    else:
        ax.set_yticklabels([])
    ax.set_xlim(-3.2, 3.2)
    ax.set_ylim(0, 28)
    ax.tick_params(length=2.5, width=0.65)
    return image


def make_2d_figure(data: dict[str, object]) -> None:
    range_axis = np.asarray(data["rangeAxis"], dtype=float).reshape(-1)
    velocity_axis = np.asarray(data["velocityAxis"], dtype=float).reshape(-1)
    rd_random = np.asarray(data["RDrandomDb"], dtype=float)
    rd_opt = np.asarray(data["RDoptimizedDb"], dtype=float)
    targets = data["targets"]
    det_random = data["randomDetection"]
    det_opt = data["optimizedDetection"]
    improvement = np.asarray(data["rdPeakImprovementDb"], dtype=float).reshape(-1)

    rd_random_crop, range_crop, velocity_crop = crop_rd(rd_random, range_axis, velocity_axis, (0, 28), (-3.2, 3.2))
    rd_opt_crop, _, _ = crop_rd(rd_opt, range_axis, velocity_axis, (0, 28), (-3.2, 3.2))
    vmax = float(np.nanmax([rd_random_crop.max(), rd_opt_crop.max()]))
    clim = (vmax - 48, vmax)

    fig = plt.figure(figsize=(7.2, 4.25), constrained_layout=True)
    gs = fig.add_gridspec(2, 3, width_ratios=[1.1, 1.1, 0.85], height_ratios=[1, 0.88])
    ax_a = fig.add_subplot(gs[:, 0])
    ax_b = fig.add_subplot(gs[:, 1])
    ax_c = fig.add_subplot(gs[0, 2])
    ax_d = fig.add_subplot(gs[1, 2])

    image = draw_heatmap(ax_a, rd_random_crop, range_crop, velocity_crop, "Random RIS", clim, targets, det_random, True)
    draw_heatmap(ax_b, rd_opt_crop, range_crop, velocity_crop, "Fixed-grid ZF-SNR RIS", clim, targets, det_opt, False)
    cbar = fig.colorbar(image, ax=[ax_a, ax_b], fraction=0.035, pad=0.02)
    cbar.set_label("Magnitude (dB)")
    cbar.ax.tick_params(length=2.5, width=0.65)

    target_ids = np.arange(1, improvement.size + 1)
    random_peaks = field(det_random, "peakDb")
    opt_peaks = field(det_opt, "peakDb")
    ax_c.plot(target_ids, random_peaks, "o-", color="#555555", lw=0.9, ms=3.2, label="random")
    ax_c.plot(target_ids, opt_peaks, "o-", color="#0072B2", lw=0.9, ms=3.2, label="optimized")
    for tid, y0, y1 in zip(target_ids, random_peaks, opt_peaks):
        ax_c.plot([tid, tid], [y0, y1], color="#A6CEE3", lw=0.8, zorder=0)
    ax_c.set_xticks(target_ids)
    ax_c.set_xticklabels([f"T{i}" for i in target_ids])
    ax_c.set_ylabel("Local peak (dB)")
    ax_c.set_title("Peak recovery")
    ax_c.legend(loc="lower right", handlelength=1.6)
    ax_c.grid(axis="y", color="#D9D9D9", lw=0.45)

    ax_d.bar(target_ids, improvement, color="#56B4E9", edgecolor="#2F5D7C", linewidth=0.45)
    ax_d.axhline(0, color="black", lw=0.6)
    ax_d.set_xticks(target_ids)
    ax_d.set_xticklabels([f"T{i}" for i in target_ids])
    ax_d.set_ylabel("Gain (dB)")
    ax_d.set_title(f"Improvement, mean {improvement.mean():.2f} dB")
    ax_d.set_ylim(0, max(12, improvement.max() + 1))
    ax_d.grid(axis="y", color="#D9D9D9", lw=0.45)

    for ax, label in zip([ax_a, ax_b, ax_c, ax_d], ["a", "b", "c", "d"]):
        add_panel_label(ax, label)

    export_figure(fig, "stage4_rd_four_targets_nature_2d")
    plt.close(fig)


def surface_panel(
    ax,
    rd_db: np.ndarray,
    range_axis: np.ndarray,
    velocity_axis: np.ndarray,
    title: str,
    zlim: tuple[float, float],
    detection,
) -> None:
    rd_crop, r_crop, v_crop = crop_rd(rd_db, range_axis, velocity_axis, (0, 28), (-3.2, 3.2))
    stride_r = max(1, rd_crop.shape[0] // 90)
    stride_v = max(1, rd_crop.shape[1] // 80)
    rd_plot = rd_crop[::stride_r, ::stride_v]
    r_plot = r_crop[::stride_r]
    v_plot = v_crop[::stride_v]
    V, R = np.meshgrid(v_plot, r_plot)
    ax.plot_surface(V, R, rd_plot, cmap=cm.viridis, linewidth=0, antialiased=True, alpha=0.96)
    ax.scatter(
        field(detection, "peakVelocity_mps"),
        field(detection, "peakRange_m"),
        field(detection, "peakDb") + 1.2,
        c="#D62728",
        s=22,
        marker="x",
        linewidths=1.0,
        depthshade=False,
    )
    for idx, (vel, rng, peak) in enumerate(
        zip(field(detection, "peakVelocity_mps"), field(detection, "peakRange_m"), field(detection, "peakDb")),
        start=1,
    ):
        ax.text(vel + 0.08, rng + 0.15, peak + 2.4, f"T{idx}", fontsize=6, color="#9C1B1B")
    ax.set_title(title, pad=4)
    ax.set_xlabel("Velocity (m s$^{-1}$)", labelpad=-1)
    ax.set_ylabel("Range (m)", labelpad=-1)
    ax.set_zlabel("Magnitude (dB)", labelpad=-1)
    ax.set_xlim(-3.2, 3.2)
    ax.set_ylim(0, 28)
    ax.set_zlim(zlim)
    ax.view_init(elev=29, azim=-54)
    ax.set_box_aspect((1.15, 1.15, 0.55))
    ax.tick_params(axis="both", which="major", pad=-2, labelsize=6)
    ax.tick_params(axis="z", which="major", pad=0, labelsize=6)
    ax.grid(False)
    ax.xaxis.pane.set_facecolor((1, 1, 1, 0))
    ax.yaxis.pane.set_facecolor((1, 1, 1, 0))
    ax.zaxis.pane.set_facecolor((1, 1, 1, 0))


def make_3d_figure(data: dict[str, object]) -> None:
    range_axis = np.asarray(data["rangeAxis"], dtype=float).reshape(-1)
    velocity_axis = np.asarray(data["velocityAxis"], dtype=float).reshape(-1)
    rd_random = np.asarray(data["RDrandomDb"], dtype=float)
    rd_opt = np.asarray(data["RDoptimizedDb"], dtype=float)
    det_random = data["randomDetection"]
    det_opt = data["optimizedDetection"]

    random_crop, _, _ = crop_rd(rd_random, range_axis, velocity_axis, (0, 28), (-3.2, 3.2))
    opt_crop, _, _ = crop_rd(rd_opt, range_axis, velocity_axis, (0, 28), (-3.2, 3.2))
    vmax = float(np.nanmax([random_crop.max(), opt_crop.max()]))
    zlim = (vmax - 55, vmax + 3)

    fig = plt.figure(figsize=(7.2, 3.25))
    ax_a = fig.add_subplot(1, 2, 1, projection="3d")
    ax_b = fig.add_subplot(1, 2, 2, projection="3d")
    surface_panel(ax_a, rd_random, range_axis, velocity_axis, "Random RIS", zlim, det_random)
    surface_panel(ax_b, rd_opt, range_axis, velocity_axis, "Fixed-grid ZF-SNR RIS", zlim, det_opt)
    ax_a.text2D(-0.02, 0.98, "a", transform=ax_a.transAxes, fontsize=9, fontweight="bold")
    ax_b.text2D(-0.02, 0.98, "b", transform=ax_b.transAxes, fontsize=9, fontweight="bold")
    fig.subplots_adjust(left=0.00, right=0.99, bottom=0.03, top=0.93, wspace=0.02)
    export_figure(fig, "stage4_rd_four_targets_nature_3d")
    plt.close(fig)


def main() -> None:
    configure_matplotlib()
    data = load_source()
    make_2d_figure(data)
    make_3d_figure(data)
    print(f"Saved Nature-style figures under {FIGURE_DIR}")


if __name__ == "__main__":
    main()
