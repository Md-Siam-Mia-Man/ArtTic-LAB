# pipelines/base_pipeline.py
import torch
import intel_extension_for_pytorch as ipex
import logging

logger = logging.getLogger("arttic_lab")


class ArtTicPipeline:
    def __init__(self, model_path, dtype=torch.bfloat16):
        if not torch.xpu.is_available():
            raise RuntimeError("Intel ARC GPU (XPU) not detected.")
        self.pipe = None
        self.model_path = model_path
        self.dtype = dtype
        self.is_optimized = False
        self.is_offloaded = False

        # Subclasses should define these
        self.t2i_class = None
        self.i2i_class = None

    def load_pipeline(self, progress):
        raise NotImplementedError("Subclasses must implement load_pipeline")

    def ensure_mode(self, mode):
        """
        Ensures the pipeline is in the correct mode ('txt2img' or 'img2img').
        Swaps the pipeline class while preserving loaded components (weights).
        """
        if not self.pipe:
            return

        target_class = self.i2i_class if mode == "img2img" else self.t2i_class

        if target_class is None:
            logger.warning(
                f"Pipeline mode '{mode}' is not supported for this model type."
            )
            return

        # If already instance of target class, do nothing
        if isinstance(self.pipe, target_class):
            return

        logger.info(f"Switching pipeline mode to {mode} ({target_class.__name__})...")

        # Swap pipeline using existing components to avoid reloading VRAM
        # We allow_patterns/ignore_patterns to avoid warnings, though strictly passing components is usually clean
        try:
            self.pipe = target_class(**self.pipe.components)
        except Exception as e:
            logger.error(f"Failed to switch pipeline mode: {e}")
            raise RuntimeError(f"Could not switch to {mode} mode.") from e

        # Re-apply device placement
        if self.is_offloaded:
            self.pipe.enable_model_cpu_offload()
        else:
            self.pipe.to("xpu")

        # Re-apply IPEX optimization if it was enabled (components are same, but container changed)
        # Note: The components (unet, vae) themselves remain optimized, so we just flag the pipe.

    def place_on_device(self, use_cpu_offload=False):
        if not self.pipe:
            raise RuntimeError("Pipeline must be loaded before placing on device.")

        if use_cpu_offload:
            logger.info("Enabling Model CPU Offload for low VRAM usage.")
            self.pipe.enable_model_cpu_offload()
            self.is_offloaded = True
        else:
            logger.info("Moving model to XPU (ARC GPU) for maximum performance.")
            self.pipe.to("xpu")
            self.is_offloaded = False

    def optimize_with_ipex(self, progress):
        if self.is_optimized:
            logger.info("Model components are already optimized.")
            return
        if self.is_offloaded:
            logger.warning("IPEX optimization is not available in CPU Offload mode.")
            return
        if not self.pipe:
            raise RuntimeError("Pipeline must be loaded before optimization.")

        progress(0.8, "Optimizing model with IPEX...")

        # Optimize core components.
        # Since these are shared objects, they stay optimized even if we swap the Pipeline wrapper.
        if hasattr(self.pipe, "unet") and self.pipe.unet:
            self.pipe.unet = ipex.optimize(
                self.pipe.unet.eval(), dtype=self.dtype, inplace=True
            )
            logger.info("U-Net optimized with IPEX.")
        elif hasattr(self.pipe, "transformer") and self.pipe.transformer:
            self.pipe.transformer = ipex.optimize(
                self.pipe.transformer.eval(), dtype=self.dtype, inplace=True
            )
            logger.info("Transformer optimized with IPEX.")

        if hasattr(self.pipe, "vae") and self.pipe.vae:
            self.pipe.vae = ipex.optimize(
                self.pipe.vae.eval(), dtype=self.dtype, inplace=True
            )
            logger.info("VAE optimized with IPEX.")

        self.is_optimized = True

    def generate(self, *args, **kwargs):
        if not self.pipe:
            raise RuntimeError("Pipeline not loaded.")
        with torch.xpu.amp.autocast(enabled=True, dtype=self.dtype):
            return self.pipe(*args, **kwargs)
