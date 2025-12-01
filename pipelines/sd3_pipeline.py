import torch
from diffusers import StableDiffusion3Pipeline, StableDiffusion3Img2ImgPipeline
from .base_pipeline import ArtTicPipeline
import logging

logger = logging.getLogger("arttic_lab")

SD3_BASE_MODEL_REPO = "stabilityai/stable-diffusion-3-medium-diffusers"


class SD3Pipeline(ArtTicPipeline):
    def __init__(self, model_path, dtype=None):
        super().__init__(model_path, dtype)
        self.t2i_class = StableDiffusion3Pipeline
        self.i2i_class = StableDiffusion3Img2ImgPipeline

    def load_pipeline(self, progress):
        progress(0.2, "Loading base SD3 components from Hugging Face...")
        try:
            self.pipe = self.t2i_class.from_pretrained(
                SD3_BASE_MODEL_REPO,
                torch_dtype=self.dtype,
                use_safetensors=True,
                progress_bar_config={"disable": True},
            )
        except Exception as e:
            logger.error(
                f"Failed to download SD3 base model. Check internet connection. Error: {e}"
            )
            raise RuntimeError(
                "Could not download base SD3 components from Hugging Face."
            )

        progress(0.5, "Injecting local model weights...")
        self.pipe.load_lora_weights(self.model_path)
        logger.info(f"Successfully injected weights from '{self.model_path}'")
