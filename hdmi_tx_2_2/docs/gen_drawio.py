#!/usr/bin/env python3
"""Generate draw.io architecture diagrams for hdmi_tx_2_2."""

import html
import textwrap
from pathlib import Path

OUT = Path(__file__).parent / "hdmi_tx_architecture.drawio"

BOX = "rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;fontSize=11;"
BOX_G = "rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;fontSize=11;"
BOX_O = "rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=11;"
BOX_P = "rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;fontSize=11;"
BOX_Y = "rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=11;"
LANE = "swimlane;whiteSpace=wrap;html=1;startSize=28;fillColor=#f5f5f5;strokeColor=#666666;fontStyle=1;fontSize=12;"
IO = "rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontSize=11;dashed=1;"
NOTE = "text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;fontSize=10;fontColor=#666666;"
EDGE = (
    "edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;"
    "jettySize=auto;html=1;strokeColor=#333333;strokeWidth=1;"
)
EDGE_D = EDGE + "dashed=1;strokeColor=#888888;"

cid = 2
cells = []


def esc(s: str) -> str:
    return html.escape(s)


def box(x, y, w, h, label, style=BOX, parent="1"):
    global cid
    i = str(cid)
    cid += 1
    cells.append(
        f'        <mxCell id="{i}" value="{esc(label)}" style="{style}" '
        f'vertex="1" parent="{parent}">'
        f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>'
    )
    return i


def note(x, y, w, h, label, parent="1"):
    global cid
    i = str(cid)
    cid += 1
    cells.append(
        f'        <mxCell id="{i}" value="{esc(label)}" style="{NOTE}" '
        f'vertex="1" parent="{parent}">'
        f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>'
    )
    return i


def lane(x, y, w, h, title):
    global cid
    i = str(cid)
    cid += 1
    cells.append(
        f'        <mxCell id="{i}" value="{esc(title)}" style="{LANE}" '
        f'vertex="1" parent="1">'
        f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>'
    )
    return i


def edge(
    src,
    dst,
    style=EDGE,
    label="",
    points=None,
    exit_x=None,
    exit_y=None,
    entry_x=None,
    entry_y=None,
):
    global cid
    i = str(cid)
    cid += 1
    val = f' value="{esc(label)}"' if label else ""
    extra = ""
    if exit_x is not None:
        extra += f"exitX={exit_x};exitY={exit_y if exit_y is not None else 0.5};"
    if entry_x is not None:
        extra += f"entryX={entry_x};entryY={entry_y if entry_y is not None else 0.5};"
    style_full = style + extra

    pts_xml = ""
    if points:
        pts = "\n".join(
            f'              <mxPoint x="{px}" y="{py}"/>' for px, py in points
        )
        pts_xml = f"<Array as=\"points\">\n{pts}\n            </Array>"

    cells.append(
        f'        <mxCell id="{i}"{val} style="{style_full}" edge="1" parent="1" '
        f'source="{src}" target="{dst}">'
        f'<mxGeometry relative="1" as="geometry">{pts_xml}</mxGeometry></mxCell>'
    )
    return i


def build_rtl():
    global cells, cid
    cells = []
    cid = 2

    PW = 1760

    # ── External IO (aligned above the blocks they connect to) ──
    l_io = lane(40, 30, PW, 95, "External interfaces")
    io_reg = box(30, 38, 120, 48, "Reg bus\n0x00–0x2C", IO, l_io)
    io_hpd = box(200, 38, 80, 48, "HPD", IO, l_io)
    io_ddc = box(430, 38, 120, 48, "DDC I²C", IO, l_io)
    io_vid = box(700, 38, 120, 48, "Video in\nvid_clk", IO, l_io)
    io_i2s = box(1180, 38, 90, 48, "I2S", IO, l_io)
    io_phy = box(1480, 38, 140, 48, "PHY out\nlanes", IO, l_io)

    # ── Control — single left→right pipeline ──
    l_axi = lane(40, 145, PW, 175, "Control domain — axi_clk")
    reg = box(30, 48, 130, 72, "Register block\nCTRL / VIDEO_CFG\nLINK_CFG / ULTRA96", BOX, l_axi)
    fsm = box(200, 48, 140, 72, "hdmi_tx_fsm\nHPD→EDID→MODE_CALC\n→SCDC→FRL_LT→ACTIVE", BOX_G, l_axi)
    ddc = box(380, 48, 130, 72, "hdmi_ddc_bus\nEDID + SCDC", BOX, l_axi)
    edid = box(550, 48, 130, 72, "hdmi_edid_parser\nsink caps", BOX, l_axi)
    mode = box(720, 48, 140, 72, "hdmi_mode_calc\nTMDS/FRL DSC/VRR\nLIP/FEC Ultra96", BOX_G, l_axi)
    frlt = box(900, 48, 120, 72, "hdmi_frl_lt\nlink training", BOX, l_axi)
    aud = box(1180, 48, 110, 72, "hdmi_audio_in", BOX_O, l_axi)

    # ── Video — under video-in column ──
    l_vid = lane(40, 340, PW, 110, "Video domain — vid_clk")
    csc = box(700, 42, 130, 58, "hdmi_vid_csc\nRGB/YUV/10bpc", BOX_Y, l_vid)
    dsc = box(880, 42, 150, 58, "hdmi_dsc_wrap\nPPS + encoder", BOX_Y, l_vid)

    # ── Link — metadata row, packetizer, encoder row ──
    l_link = lane(40, 470, PW, 250, "Link domain — link_clk")
    game = box(30, 42, 110, 50, "gaming_meta\n(scaffold)", BOX_P, l_link)
    ifr = box(170, 42, 120, 50, "infoframe_gen\nAVI", BOX_P, l_link)
    lip = box(320, 42, 100, 50, "lip_gen\nLatency IF", BOX_P, l_link)
    pkt = box(500, 38, 160, 58, "hdmi_packetizer\nlanes 0–3", BOX_G, l_link)
    tmds = box(500, 155, 120, 52, "hdmi_tmds_link\n8b/10b", BOX, l_link)
    frl = box(660, 155, 110, 52, "hdmi_frl_link\n4-lane", BOX, l_link)
    fec = box(810, 155, 110, 52, "hdmi_frl_fec\nRS-FEC", BOX, l_link)
    mux = box(960, 155, 120, 52, "hdmi_link_mux", BOX_G, l_link)

    note(30, 220, 200, 20, "dashed = enable / config", l_axi)

    # Vertical IO drops (straight down)
    edge(io_reg, reg, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)
    edge(io_hpd, fsm, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)
    edge(io_ddc, ddc, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)
    edge(ddc, io_ddc, EDGE_D, label="SCL/SDA", exit_x=0.5, exit_y=0, entry_x=0.5, entry_y=1)
    edge(io_vid, csc, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(760, 125), (765, 125)])
    edge(io_i2s, aud, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(1225, 125), (1235, 125)])
    edge(mux, io_phy, label="phy_data", exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5,
         points=[(1700, 597), (1700, 54)])
    edge(io_phy, frlt, EDGE_D, label="phy_ready(in)", exit_x=0.5, exit_y=1, entry_x=1, entry_y=0.5,
         points=[(1550, 86), (1550, 221)])

    # Control pipeline (horizontal, same row)
    edge(reg, fsm, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(reg, mode, EDGE_D, label="cfg", exit_x=1, exit_y=0.75, entry_x=0, entry_y=0.75)
    edge(fsm, ddc, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(ddc, edid, label="edid_mem", exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(edid, mode, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(fsm, frlt, label="LT start", exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)

    # Video pipeline
    edge(csc, dsc, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(mode, dsc, EDGE_D, label="dsc_en", exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(790, 221), (955, 221), (955, 382)])

    # Video → packetizer (route down right side)
    edge(dsc, pkt, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(955, 450), (580, 450)])

    # Audio → packetizer (route along right margin)
    edge(aud, pkt, exit_x=0.5, exit_y=1, entry_x=1, entry_y=0.5,
         points=[(1235, 330), (1235, 530), (700, 530)])

    # Metadata / control → packetizer
    edge(mode, game, EDGE_D, label="vrr/allm", exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(790, 221), (85, 221), (85, 512)])
    edge(mode, ifr, EDGE_D, label="vic/vrr", exit_x=0.5, exit_y=1, entry_x=0, entry_y=0.5,
         points=[(790, 250), (120, 250)])
    edge(fsm, ifr, EDGE_D, label="if_load", exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(270, 221), (230, 221), (230, 512)])
    edge(fsm, lip, EDGE_D, label="lip_load", exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(270, 240), (370, 240), (370, 512)])
    edge(ifr, pkt, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.35)
    edge(lip, pkt, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.45)

    # Reg → LIP (left margin route)
    edge(reg, lip, EDGE_D, "LIP_CFG", exit_x=0, exit_y=0.5, entry_x=0, entry_y=0.5,
         points=[(20, 221), (20, 534)])

    # FSM enable → packetizer (left margin, dashed)
    edge(fsm, pkt, EDGE_D, "pkt_enable", exit_x=0, exit_y=0.5, entry_x=0, entry_y=0.5,
         points=[(55, 221), (55, 534)])

    # Link encoder pipeline
    edge(pkt, tmds, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)
    edge(pkt, frl, exit_x=0.5, exit_y=1, entry_x=0, entry_y=0.5,
         points=[(580, 620), (640, 620)])
    edge(frl, fec, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(tmds, mux, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(fec, mux, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)

    return "\n".join(cells)


def build_uvm():
    global cells, cid
    cells = []
    cid = 2

    PW = 1760

    # ── Tests (top row, no outgoing edges — avoids clutter) ──
    l_test = lane(40, 30, PW, 95, "Tests  (hdmi_tx_*_test)")
    t_full = box(30, 40, 195, 48, "hdmi22_full_test\n(primary)", BOX_G, l_test)
    t_regr = box(245, 40, 195, 48, "spec_regression_test", BOX_G, l_test)
    t_p1 = box(460, 40, 155, 48, "spec_phase1_test", BOX, l_test)
    t_p2 = box(635, 40, 155, 48, "spec_phase2_test", BOX, l_test)
    t_p2b = box(810, 40, 165, 48, "spec_phase2b_test", BOX, l_test)
    t_p3 = box(995, 40, 155, 48, "spec_phase3_test", BOX, l_test)

    # ── Sequences (second row, drives agents) ──
    l_seq = lane(40, 145, PW, 95, "Sequences")
    s_sink = box(30, 40, 175, 48, "sink_connect_seq", BOX_O, l_seq)
    s_bring = box(230, 40, 175, 48, "link_bringup_seq", BOX_O, l_seq)
    s_audit = box(430, 40, 165, 48, "reg_audit_seq", BOX_O, l_seq)
    s_vid = box(615, 40, 165, 48, "vid_stress_seq", BOX_O, l_seq)
    note(820, 48, 280, 36, "spec_phase_base_test → spec_validator\nspec_pkg → apply_spec_phase()", l_seq)

    # ── TB (left column) ──
    l_tb = lane(40, 260, 520, 340, "hdmi_tx_tb")
    dut = box(180, 45, 150, 60, "hdmi_tx_top\n(DUT)", BOX_G, l_tb)
    slave = box(30, 45, 130, 60, "ddc_slave\nI²C model", BOX, l_tb)
    sva = box(30, 130, 140, 48, "bind: assertions", BOX_O, l_tb)
    lc = box(190, 130, 140, 48, "bind: link_checker", BOX_O, l_tb)
    if_reg = box(30, 210, 95, 40, "reg_if", IO, l_tb)
    if_vid = box(140, 210, 95, 40, "vid_if", IO, l_tb)
    if_sink = box(250, 210, 95, 40, "sink_if", IO, l_tb)
    if_phy = box(360, 210, 95, 40, "phy_if", IO, l_tb)
    if_fsm = box(30, 270, 95, 40, "fsm_if", IO, l_tb)

    # ── Env (right column) ──
    l_env = lane(600, 260, 1200, 340, "hdmi_tx_env")
    cfg = box(30, 42, 130, 44, "env_config", BOX_Y, l_env)
    spec_pkg = box(180, 42, 155, 44, "hdmi_tx_spec_pkg", BOX_Y, l_env)

    reg_agt = box(30, 110, 140, 56, "reg_agent\ndrv + mon", BOX, l_env)
    vid_agt = box(190, 110, 140, 56, "vid_agent\ndrv + mon", BOX, l_env)
    sink_agt = box(350, 110, 140, 56, "sink_agent\ndrv", BOX, l_env)
    phy_agt = box(510, 110, 140, 56, "phy_agent\nmon", BOX, l_env)

    chk = box(30, 200, 155, 64, "hdmi_tx_checker\n(scoreboard)", BOX_G, l_env)
    cov = box(205, 210, 120, 48, "coverage", BOX_P, l_env)
    ref = box(345, 210, 125, 48, "ref_model", BOX_P, l_env)
    spec_v = box(490, 200, 155, 64, "spec_validator\n§4–§5", BOX_P, l_env)

    edge(t_full, s_bring, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(127, 125), (317, 125)])
    edge(t_full, s_vid, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(127, 125), (697, 125)])
    edge(t_full, s_sink, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(127, 125), (117, 125)])

    # ── Sequence → agent (vertical, one per column) ──
    edge(s_sink, sink_agt, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(117, 240), (425, 240), (425, 370)])
    edge(s_bring, reg_agt, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(317, 240), (100, 240), (100, 370)])
    edge(s_audit, reg_agt, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(512, 240), (100, 240)])
    edge(s_vid, vid_agt, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(697, 240), (260, 240), (260, 370)])

    # Agent → interface → DUT (horizontal through gap)
    edge(reg_agt, if_reg, exit_x=0, exit_y=0.5, entry_x=1, entry_y=0.5)
    edge(vid_agt, if_vid, exit_x=0, exit_y=0.5, entry_x=1, entry_y=0.5)
    edge(sink_agt, if_sink, exit_x=0, exit_y=0.5, entry_x=1, entry_y=0.5)
    edge(if_reg, dut, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.75)
    edge(if_vid, dut, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.85)
    edge(if_sink, dut, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.55)
    edge(dut, if_phy, label="mon", exit_x=1, exit_y=0.65, entry_x=0, entry_y=0.5)
    edge(if_phy, phy_agt, label="mon", exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(dut, if_fsm, EDGE_D, exit_x=1, exit_y=0.75, entry_x=0, entry_y=0.5)

    # DDC slave ↔ DUT
    edge(slave, dut, exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5, label="I²C")

    # Binds
    edge(dut, sva, EDGE_D, exit_x=0, exit_y=1, entry_x=0.5, entry_y=0)
    edge(dut, lc, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)

    # Monitor → checker (down within env, no cross-lane)
    edge(reg_agt, chk, EDGE_D, label="mon", exit_x=0.5, exit_y=1, entry_x=0.25, entry_y=0)
    edge(vid_agt, chk, EDGE_D, label="mon", exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)
    edge(phy_agt, chk, EDGE_D, label="mon", exit_x=0.5, exit_y=1, entry_x=0.75, entry_y=0)
    edge(reg_agt, cov, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0, entry_y=0.5)
    edge(if_fsm, chk, EDGE_D, label="FSM", exit_x=1, exit_y=0.5, entry_x=0, entry_y=1,
         points=[(560, 550), (560, 620), (630, 620)])

    # Checker → ref; test → spec_validator
    edge(chk, ref, EDGE_D, label="uses", exit_x=1, exit_y=0.5, entry_x=0, entry_y=0.5)
    edge(t_full, spec_v, EDGE_D, label="audit", exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(127, 125), (567, 125)])

    # Config / spec_pkg (dashed, top of env)
    edge(cfg, reg_agt, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(95, 350), (95, 350)])
    edge(cfg, vid_agt, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0,
         points=[(257, 350), (257, 350)])
    edge(spec_pkg, spec_v, EDGE_D, exit_x=0.5, exit_y=1, entry_x=0.5, entry_y=0)
    edge(spec_pkg, cfg, EDGE_D, exit_x=0, exit_y=0.5, entry_x=1, entry_y=0.5)

    return "\n".join(cells)


def wrap_diagram(name: str, diagram_id: str, body: str, page_h: int = 1200) -> str:
    return textwrap.dedent(f"""
    <diagram id="{diagram_id}" name="{name}">
      <mxGraphModel dx="1422" dy="900" grid="1" gridSize="10" guides="1" tooltips="1"
          connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1840"
          pageHeight="{page_h}" math="0" shadow="0">
        <root>
          <mxCell id="0"/>
          <mxCell id="1" parent="0"/>
{body}
        </root>
      </mxGraphModel>
    </diagram>""")


def main():
    rtl = build_rtl()
    uvm = build_uvm()

    content = textwrap.dedent(f"""<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" agent="hdmi_tx_2_2" version="24.0.0" type="device">
{wrap_diagram("RTL Architecture", "rtl-arch", rtl, 760)}
{wrap_diagram("UVM Verification", "uvm-arch", uvm, 640)}
</mxfile>
""")
    OUT.write_text(content)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
